# Extract OVF descriptor directly from OVA (no vCenter needed)
# OVA = tar archive containing .ovf XML + .vmdk files

$VCFInstallerOVA = "E:\VCF-SDDC-Manager-Appliance-9.0.1.0.24962180.ova"
$OutFile         = "$PSScriptRoot\vcf9installer-ovf-props.txt"
$out             = [System.Collections.Generic.List[string]]::new()

$out.Add("VCF9 Installer OVA - OVF Descriptor Properties")
$out.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$out.Add("=" * 70)

# ── Extract .ovf from tar (OVA is a POSIX tar) ──────────────────────
Write-Host "Reading OVA archive: $VCFInstallerOVA ..." -ForegroundColor Cyan

try {
    $fs     = [System.IO.File]::OpenRead($VCFInstallerOVA)
    $buffer = New-Object byte[] 512
    $ovfXml = $null

    while ($fs.Position -lt $fs.Length) {
        # Read 512-byte tar header block
        $read = $fs.Read($buffer, 0, 512)
        if ($read -lt 512) { break }

        # File name is first 100 bytes, null-terminated
        $nameBytes = $buffer[0..99]
        $nullIdx   = [Array]::IndexOf($nameBytes, [byte]0)
        if ($nullIdx -ge 0) { $nameBytes = $nameBytes[0..($nullIdx-1)] }
        $fileName  = [System.Text.Encoding]::ASCII.GetString($nameBytes).Trim()

        if ($fileName -eq "") { break }  # end-of-archive

        # File size is bytes 124-135 (octal string)
        $sizeStr  = [System.Text.Encoding]::ASCII.GetString($buffer[124..134]).Trim().TrimEnd([char]0)
        $fileSize = [Convert]::ToInt64($sizeStr, 8)

        Write-Host "  Found: $fileName ($fileSize bytes)"

        if ($fileName -match "\.ovf$") {
            # Read file content
            $content = New-Object byte[] $fileSize
            $fs.Read($content, 0, $fileSize) | Out-Null
            $ovfXml  = [System.Text.Encoding]::UTF8.GetString($content)
            Write-Host "  --> Extracted OVF descriptor!" -ForegroundColor Green
        } else {
            # Skip file data + padding to next 512-byte boundary
            $skip    = $fileSize
            $padding = if ($fileSize % 512 -ne 0) { 512 - ($fileSize % 512) } else { 0 }
            $fs.Seek($skip + $padding, [System.IO.SeekOrigin]::Current) | Out-Null
        }

        if ($ovfXml) { break }
    }
    $fs.Close()
} catch {
    $out.Add("ERROR reading OVA: $_")
    $ovfXml = $null
}

if ($ovfXml) {
    # Parse XML and extract UserConfigurable properties
    [xml]$xml = $ovfXml

    $out.Add("")
    $out.Add("--- UserConfigurable OVF Properties ---")

    $ns = @{ ovf = "http://schemas.dmtf.org/ovf/envelope/1" }
    $props = $xml.Envelope.VirtualSystem.ProductSection.Property |
             Where-Object { $_.'ovf:userConfigurable' -eq 'true' -or $_.userConfigurable -eq 'true' }

    if (-not $props) {
        # Try without namespace filter
        $props = $xml.Envelope.VirtualSystem.ProductSection.Property
    }
    if (-not $props) {
        # Try nested VirtualSystemCollection
        $props = $xml.Envelope.VirtualSystemCollection.VirtualSystem.ProductSection.Property
    }

    if ($props) {
        foreach ($p in $props) {
            $key  = $p.'ovf:key'   ?? $p.key
            $type = $p.'ovf:type'  ?? $p.type
            $desc = ($p.Description.'#text') ?? $p.Description
            $out.Add("  KEY : $key")
            $out.Add("  TYPE: $type  |  DESC: $desc")
            $out.Add("")
        }
    } else {
        $out.Add("(no properties found in standard location)")
    }

    # Also dump all ProductSection keys
    $out.Add("--- All ProductSection nodes ---")
    $xml.Envelope.VirtualSystem.ProductSection.ChildNodes | ForEach-Object {
        $out.Add("  <$($_.LocalName)> key=$($_.'ovf:key') class=$($_.'ovf:class')")
    }

    # Full OVF XML
    $out.Add("")
    $out.Add("--- Full OVF XML ---")
    $out.Add($ovfXml)
} else {
    $out.Add("Could not extract OVF descriptor from OVA.")
}

$out | Out-File -FilePath $OutFile -Encoding UTF8 -Force
Write-Host ""
Write-Host ">>> Saved to: $OutFile" -ForegroundColor Green
Write-Host "Please upload vcf9installer-ovf-props.txt"
