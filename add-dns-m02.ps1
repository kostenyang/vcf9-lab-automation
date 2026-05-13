# Add MISSING DNS Records for VCF9 M02
# Run as Administrator on the DNS Server
# Zone    : home.lab
# RevZone : 1.0.10.in-addr.arpa
#
# Already OK (skip):
#   vcf-m02-esx01~04, vc01, nsx01a, nsx01  -> A + PTR all correct
#   vcf-m02-sddcm01.home.lab -> 10.0.1.18  -> A record already exists
#
# 10.0.1.4 / 10.0.1.5  -> shared with M01, PTR not changed
#
# Need to ADD:
#   A  : vcf-m02-inst01  -> 10.0.1.4   (A only, PTR stays as M01)
#   A  : vcf-m02-ops01   -> 10.0.1.22
#   A  : vcf-m02-fleet01 -> 10.0.1.23
#   A  : vcf-m02-opsc01  -> 10.0.1.24
#   PTR: 10.0.1.18       -> vcf-m02-sddcm01.home.lab  (check if missing)
#   PTR: 10.0.1.22       -> vcf-m02-ops01.home.lab
#   PTR: 10.0.1.23       -> vcf-m02-fleet01.home.lab
#   PTR: 10.0.1.24       -> vcf-m02-opsc01.home.lab

$Zone    = "home.lab"
$RevZone = "1.0.10.in-addr.arpa"

# ── A Records to add ──────────────────────────────────────────
$aRecords = @(
    @{ Name="vcf-m02-inst01";  IP="10.0.1.4";  PTR=$false },  # PTR shared with M01, skip
    @{ Name="vcf-m02-ops01";   IP="10.0.1.22"; PTR=$true  },
    @{ Name="vcf-m02-fleet01"; IP="10.0.1.23"; PTR=$true  },
    @{ Name="vcf-m02-opsc01";  IP="10.0.1.24"; PTR=$true  }
)

# ── PTR only (sddcm01 already has A, check PTR) ──────────────
$ptrOnly = @(
    @{ IP="10.0.1.18"; FQDN="vcf-m02-sddcm01.$Zone" }
)

Write-Host "=== Adding missing VCF9 M02 DNS records ===" -ForegroundColor Cyan

foreach ($r in $aRecords) {
    $fqdn      = "$($r.Name).$Zone"
    $lastOctet = $r.IP.Split(".")[-1]

    # A Record
    try {
        Add-DnsServerResourceRecordA -ZoneName $Zone -Name $r.Name -IPv4Address $r.IP `
            -TimeToLive 01:00:00 -ErrorAction Stop
        Write-Host "[OK] A    $fqdn -> $($r.IP)" -ForegroundColor Green
    } catch {
        Write-Host "[!!] A    $fqdn : $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # PTR Record (if applicable)
    if ($r.PTR) {
        try {
            Add-DnsServerResourceRecordPtr -ZoneName $RevZone -Name $lastOctet `
                -PtrDomainName "$fqdn." -TimeToLive 01:00:00 -ErrorAction Stop
            Write-Host "[OK] PTR  $($r.IP) -> $fqdn" -ForegroundColor Green
        } catch {
            Write-Host "[!!] PTR  $($r.IP) : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# PTR only for sddcm01 (10.0.1.18)
foreach ($p in $ptrOnly) {
    $lastOctet = $p.IP.Split(".")[-1]
    try {
        Add-DnsServerResourceRecordPtr -ZoneName $RevZone -Name $lastOctet `
            -PtrDomainName "$($p.FQDN)." -TimeToLive 01:00:00 -ErrorAction Stop
        Write-Host "[OK] PTR  $($p.IP) -> $($p.FQDN)" -ForegroundColor Green
    } catch {
        Write-Host "[!!] PTR  $($p.IP) : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Verify ===" -ForegroundColor Cyan

$checkList = @(
    @{ Name="vcf-m02-inst01";  IP="10.0.1.4"  },
    @{ Name="vcf-m02-sddcm01"; IP="10.0.1.18" },
    @{ Name="vcf-m02-ops01";   IP="10.0.1.22" },
    @{ Name="vcf-m02-fleet01"; IP="10.0.1.23" },
    @{ Name="vcf-m02-opsc01";  IP="10.0.1.24" }
)

foreach ($r in $checkList) {
    $fqdn = "$($r.Name).$Zone"
    $fwd  = Resolve-DnsName $fqdn -Server 127.0.0.1 -ErrorAction SilentlyContinue |
            Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress -First 1
    $fwdOk = if ($fwd -eq $r.IP) { "OK" } else { "FAIL (got: $fwd)" }
    Write-Host ("  Fwd [{0,-4}] {1,-35} -> {2}" -f $fwdOk, $fqdn, $r.IP)
}
