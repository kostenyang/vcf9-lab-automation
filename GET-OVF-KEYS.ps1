# GET-OVF-KEYS.ps1
# 直接從 OVA 二進位檔讀取 OVF 屬性 key，不需要連 vCenter
# 執行方式: .\GET-OVF-KEYS.ps1

$OVAPath   = "E:\VCF-SDDC-Manager-Appliance-9.0.1.0.24962180.ova"
$OutFile   = "$PSScriptRoot\vcf9-ovf-keys.txt"

"=== VCF9 Installer OVF Property Keys ===" | Out-File $OutFile -Encoding UTF8
"OVA: $OVAPath"                            | Out-File $OutFile -Append -Encoding UTF8
"Date: $(Get-Date)"                         | Out-File $OutFile -Append -Encoding UTF8
"" | Out-File $OutFile -Append

if (-not (Test-Path $OVAPath)) {
    "ERROR: OVA file not found: $OVAPath" | Out-File $OutFile -Append
    Write-Host "ERROR: OVA file not found."
    exit 1
}

Write-Host "Reading first 5 MB of OVA ..."

# OVA 是 TAR 格式，OVF XML 幾乎都在最前面
# 讀前 5 MB 足以包含完整的 OVF XML
$fs = [System.IO.File]::OpenRead($OVAPath)
$bufSize = 5 * 1024 * 1024   # 5 MB
$buf = New-Object byte[] $bufSize
$read = $fs.Read($buf, 0, $bufSize)
$fs.Close()

$text = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)

# ── 1. 找所有 ovf:key ────────────────────────────────────────────────────────
"" | Out-File $OutFile -Append
"=== ALL ovf:key found ===" | Out-File $OutFile -Append
$keyMatches = [regex]::Matches($text, 'ovf:key="([^"]+)"')
if ($keyMatches.Count -gt 0) {
    $keys = $keyMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $keys | ForEach-Object { "  $_" | Out-File $OutFile -Append }
    "Total: $($keys.Count) unique keys" | Out-File $OutFile -Append
} else {
    "  (none found)" | Out-File $OutFile -Append
}

# ── 2. 找所有 ovf:category（分組標題）────────────────────────────────────────
"" | Out-File $OutFile -Append
"=== Property Categories ===" | Out-File $OutFile -Append
$catMatches = [regex]::Matches($text, 'ovf:category="([^"]+)"')
if ($catMatches.Count -gt 0) {
    $catMatches | ForEach-Object { "  $($_.Groups[1].Value)" } | Sort-Object -Unique |
        Out-File $OutFile -Append
} else {
    "  (none)" | Out-File $OutFile -Append
}

# ── 3. 擷取完整 <ProductSection> 內容（最完整的屬性資訊）─────────────────────
"" | Out-File $OutFile -Append
"=== Full ProductSection XML ===" | Out-File $OutFile -Append
$psMatch = [regex]::Match($text, '<ProductSection[^>]*>[\s\S]+?</ProductSection>', 'Singleline')
if ($psMatch.Success) {
    $psMatch.Value | Out-File $OutFile -Append
} else {
    "  (ProductSection not found in first 5 MB)" | Out-File $OutFile -Append
    # 如果找不到，把 Property 相關的 XML 行都輸出
    "" | Out-File $OutFile -Append
    "=== Lines containing 'Property' or 'key=' ===" | Out-File $OutFile -Append
    $lines = $text -split "`n"
    $lines | Where-Object { $_ -match 'Property|ovf:key|guestinfo|vami|ADMIN|ROOT_PASS' } |
        Out-File $OutFile -Append
}

Write-Host "Done! Open: $OutFile"
