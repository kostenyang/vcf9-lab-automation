# DNS Check for VCF9 M02 - uses nslookup (compatible with all Windows versions)
# Output: check-dns-m02-results.txt  (same folder as this script)

$DnsServer  = "127.0.0.1"
$Zone       = "home.lab"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }
$OutputFile = Join-Path $ScriptDir "check-dns-m02-results.txt"

$records = @(
    [PSCustomObject]@{ Name="vcf-m02-inst01";  IP="10.0.1.4"  },
    [PSCustomObject]@{ Name="vcf-m02-sddcm01"; IP="10.0.1.5"  },
    [PSCustomObject]@{ Name="vcf-m02-esx01";   IP="10.0.1.14" },
    [PSCustomObject]@{ Name="vcf-m02-esx02";   IP="10.0.1.15" },
    [PSCustomObject]@{ Name="vcf-m02-esx03";   IP="10.0.1.16" },
    [PSCustomObject]@{ Name="vcf-m02-esx04";   IP="10.0.1.17" },
    [PSCustomObject]@{ Name="vcf-m02-vc01";    IP="10.0.1.19" },
    [PSCustomObject]@{ Name="vcf-m02-nsx01a";  IP="10.0.1.20" },
    [PSCustomObject]@{ Name="vcf-m02-nsx01";   IP="10.0.1.21" },
    [PSCustomObject]@{ Name="vcf-m02-ops01";   IP="10.0.1.22" },
    [PSCustomObject]@{ Name="vcf-m02-fleet01"; IP="10.0.1.23" },
    [PSCustomObject]@{ Name="vcf-m02-opsc01";  IP="10.0.1.24" }
)

$out    = [System.Collections.Generic.List[string]]::new()
$issues = [System.Collections.Generic.List[string]]::new()
$ipMap  = @{}

$out.Add("=" * 62)
$out.Add("  VCF9 M02 DNS CHECK REPORT")
$out.Add("  Time   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$out.Add("  Server : $DnsServer  |  Zone: $Zone")
$out.Add("=" * 62)
$out.Add("")

foreach ($r in $records) {
    $fqdn = "$($r.Name).$Zone"

    # ── Forward (A) via nslookup ──────────────────────────────
    $fwdRaw = & nslookup $fqdn $DnsServer 2>&1
    $fwdIP  = ($fwdRaw | Select-String "Address" | Select-Object -Last 1) -replace ".*Address:\s*",""
    $fwdIP  = $fwdIP.Trim()

    if ($fwdIP -eq $r.IP) {
        $fwdTag = "[OK ]"
    } elseif ($fwdIP -and $fwdIP -ne "") {
        $fwdTag = "[ERR]"
        $issues.Add("FORWARD MISMATCH : $fqdn -> got $fwdIP  (expected $($r.IP))")
    } else {
        $fwdTag = "[---]"
        $issues.Add("FORWARD MISSING  : $fqdn")
    }

    # ── Reverse (PTR) via nslookup ───────────────────────────
    $revRaw  = & nslookup $r.IP $DnsServer 2>&1
    $revName = ($revRaw | Select-String "name\s*=" -i) -replace ".*name\s*=\s*",""
    $revName = $revName.Trim().TrimEnd(".")

    if ($revName -like "*$($r.Name)*") {
        $revTag = "[OK ]"
    } elseif ($revName -and $revName -ne "") {
        $revTag = "[ERR]"
        $issues.Add("REVERSE MISMATCH : $($r.IP) -> got $revName  (expected $fqdn)")
    } else {
        $revTag = "[---]"
        $issues.Add("REVERSE MISSING  : $($r.IP)")
    }

    # ── Duplicate IP check ───────────────────────────────────
    $dupNote = ""
    if ($ipMap.ContainsKey($r.IP)) {
        $dupNote = "  *** DUPLICATE IP with $($ipMap[$r.IP]) ***"
        $issues.Add("DUPLICATE IP     : $($r.IP) shared by $($r.Name) AND $($ipMap[$r.IP])")
    } else {
        $ipMap[$r.IP] = $r.Name
    }

    $out.Add("  $($r.Name)$dupNote")
    $out.Add("    Fwd $fwdTag  $fqdn  ->  $($r.IP)   (resolved: $fwdIP)")
    $out.Add("    Rev $revTag  $($r.IP)  ->  $fqdn   (resolved: $revName)")
    $out.Add("")
}

$out.Add("=" * 62)
if ($issues.Count -eq 0) {
    $out.Add("  RESULT: ALL OK - 12 A records + 12 PTR records verified")
} else {
    $out.Add("  RESULT: $($issues.Count) ISSUE(S) FOUND:")
    foreach ($i in $issues) { $out.Add("    >> $i") }
}
$out.Add("=" * 62)

# Write to file
$out | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
# Also print to console
$out | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host ">>> Report saved to: $OutputFile" -ForegroundColor Cyan
