# ============================================================
# prepare-nestedESXi-vsan.ps1
# 用途：在 VCF 部署前，對每台 nested ESXi 套用 vSAN 必要設定
#   Nested vSAN advanced settings (William Lam workarounds)
#
# 執行時機：Nested ESXi VM 開機完成後，VCF Installer 啟動前
# ============================================================

# ── 連線資訊 ────────────────────────────────────────────────
$ESXiPassword = "VMware1!VMware1!"

# Nested ESXi 管理 IP（用來 PowerCLI 連線）
$NestedESXiHostnameToMgmtIPs = @{
    "vcf-m02-esx01" = "10.0.1.14"
    "vcf-m02-esx02" = "10.0.1.15"
    "vcf-m02-esx03" = "10.0.1.16"
    "vcf-m02-esx04" = "10.0.1.17"
}

# ============================================================
# 初始化
# ============================================================
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session 2>&1 | Out-Null

Function Write-Log {
    param([string]$msg, [string]$color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg" -ForegroundColor $color
}

$hostOrder  = $NestedESXiHostnameToMgmtIPs.Keys | Sort-Object
$viSessions = @{}

# ============================================================
# Step 0：連線到每台 ESXi
# ============================================================
Write-Log "=== Step 0: 連線到所有 nested ESXi hosts ===" "Cyan"

foreach ($hostname in $hostOrder) {
    $mgmtIP = $NestedESXiHostnameToMgmtIPs[$hostname]
    try {
        $vi = Connect-VIServer -Server $mgmtIP -User root -Password $ESXiPassword `
              -Force -WarningAction SilentlyContinue -ErrorAction Stop
        $viSessions[$hostname] = $vi
        Write-Log "  Connected: $hostname ($mgmtIP)" "Green"
    } catch {
        Write-Log "  FAILED to connect $hostname ($mgmtIP): $_" "Red"
    }
}

if ($viSessions.Count -eq 0) {
    Write-Log "無法連線任何 ESXi，請確認 VM 已開機並可連線。" "Red"
    exit 1
}

# ============================================================
# Step 1：套用 Nested vSAN Advanced Settings
# ============================================================
Write-Log "" "White"
Write-Log "=== Step 1: 套用 Nested vSAN Advanced Settings ===" "Cyan"

$advSettings = @(
    @{ Option = "/LSOM/VSANDeviceMonitoring";       Value = 0;
       Desc   = "關閉裝置監控，避免 nested 環境誤判磁碟錯誤" },
    @{ Option = "/LSOM/lsomSlowDeviceUnmount";      Value = 0;
       Desc   = "關閉慢速磁碟偵測，nested 虛擬磁碟速度本來較慢" },
    @{ Option = "/VSAN/SwapThickProvisionDisabled";  Value = 1;
       Desc   = "停用 swap thick provision，節省 nested 空間" },
    @{ Option = "/VSAN/FakeSCSIReservations";       Value = 1;
       Desc   = "讓 nested vSAN 可在 physical vSAN 上正常運作（必要）" },
    @{ Option = "/VSAN/GuestUnmap";                 Value = 1;
       Desc   = "允許 TRIM/UNMAP 指令傳遞給底層 physical vSAN" }
)

foreach ($hostname in $hostOrder) {
    if (-not $viSessions.ContainsKey($hostname)) { continue }
    $vi = $viSessions[$hostname]

    Write-Log "  Host: $hostname" "Yellow"
    $vmhost = Get-VMHost -Server $vi
    $esxcli = Get-EsxCli -VMHost $vmhost -V2 -Server $vi

    foreach ($s in $advSettings) {
        try {
            $setArgs            = $esxcli.system.settings.advanced.set.CreateArgs()
            $setArgs.option     = $s.Option
            $setArgs.intvalue   = $s.Value
            $esxcli.system.settings.advanced.set.Invoke($setArgs) | Out-Null
            Write-Log "    OK  $($s.Option) = $($s.Value)  # $($s.Desc)" "Green"
        } catch {
            Write-Log "    ERR $($s.Option): $($_.Exception.Message)" "Red"
        }
    }
}

# ============================================================
# 清理：中斷連線
# ============================================================
Write-Log "" "White"
Write-Log "=== 中斷所有 ESXi 連線 ===" "Cyan"
foreach ($hostname in $viSessions.Keys) {
    Disconnect-VIServer -Server $viSessions[$hostname] -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "  Disconnected: $hostname" "Gray"
}

Write-Log "" "White"
Write-Log "完成！Advanced settings 已套用，可繼續執行 VCF Installer。" "Cyan"
