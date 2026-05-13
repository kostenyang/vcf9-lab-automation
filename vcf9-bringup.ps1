# vcf9-bringup.ps1
# Phase 2 of VCF9 lab deployment: submit JSON to VCF Installer and monitor bringup.
# Run AFTER autodeployvcf9m01.ps1 has deployed the nested ESXi VMs and VCF Installer VM.
#
# Usage:
#   .\vcf9-bringup.ps1
#   .\vcf9-bringup.ps1 -JsonFile "vcf9-m01-config.json" -InstallerIP "10.0.1.4"

param(
    [string]$JsonFile               = "vcf9-m01-config.json",
    [string]$InstallerFQDN          = "vcf-m01-inst01.home.lab",
    [string]$InstallerIP            = "10.0.1.4",
    [string]$InstallerAdminUsername = "admin@local",
    [string]$InstallerAdminPassword = "VMw@re123!PSO777",

    # Set to $true to add skip flags into the JSON before submitting
    [bool]$SkipThumbprintValidation = $true,
    [bool]$SkipGatewayPingValidation = $true,

    # Set to $false to only submit without polling progress
    [bool]$MonitorProgress = $true,

    # Polling interval in seconds while waiting for bringup to complete
    [int]$PollIntervalSec = 120,

    # Max wait time for the Installer API to become ready (seconds)
    [int]$InstallerReadyTimeoutSec = 1800
)

$verboseLogFile = "vcf9-bringup.log"

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color = "green"
    )
    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"
    Write-Host -NoNewline -ForegroundColor White "[$timeStamp]"
    Write-Host -ForegroundColor $color " $message"
    "[$timeStamp] $message" | Out-File -Append -LiteralPath $verboseLogFile
}

Function Get-VCFInstallerToken {
    $payload = @{ "username" = $InstallerAdminUsername; "password" = $InstallerAdminPassword }
    try {
        $resp = Invoke-WebRequest -Uri "https://${InstallerIP}/v1/tokens" `
            -Method POST -SkipCertificateCheck -TimeoutSec 10 `
            -Headers @{"Content-Type"="application/json";"Accept"="application/json"} `
            -Body ($payload | ConvertTo-Json)
        $token = ($resp.Content | ConvertFrom-Json).accessToken
        return @{
            "Content-Type"  = "application/json"
            "Accept"        = "application/json"
            "Authorization" = "Bearer $token"
        }
    } catch {
        My-Logger "Failed to get VCF Installer token: $_" "red"
        exit 1
    }
}

# ── Pre-check ────────────────────────────────────────────────────────────────
if (-not (Test-Path $JsonFile)) {
    My-Logger "JSON file not found: $JsonFile" "red"
    My-Logger "Run autodeployvcf9m01.ps1 first to generate the JSON." "yellow"
    exit 1
}

if ($PSVersionTable.PSEdition -ne "Core") {
    My-Logger "PowerShell Core required. Please run with pwsh.exe." "red"
    exit 1
}

$StartTime = Get-Date
My-Logger "=== VCF9 Bringup Script Started ===" "cyan"
My-Logger "JSON file  : $JsonFile"
My-Logger "Installer  : https://$InstallerIP  ($InstallerFQDN)"

# ── Patch JSON with skip flags ────────────────────────────────────────────────
if ($SkipThumbprintValidation -or $SkipGatewayPingValidation) {
    My-Logger "Patching JSON with skip validation flags ..."
    $jsonObj = Get-Content $JsonFile -Raw | ConvertFrom-Json

    if ($SkipThumbprintValidation -and -not ($jsonObj.PSObject.Properties.Name -contains "skipEsxThumbprintValidation")) {
        $jsonObj | Add-Member -NotePropertyName "skipEsxThumbprintValidation" -NotePropertyValue $true
    }
    if ($SkipGatewayPingValidation -and -not ($jsonObj.PSObject.Properties.Name -contains "skipGatewayPingValidation")) {
        $jsonObj | Add-Member -NotePropertyName "skipGatewayPingValidation" -NotePropertyValue $true
    }

    $patchedJson = "$($JsonFile.Replace('.json',''))-patched.json"
    $jsonObj | ConvertTo-Json -Depth 20 | Out-File -LiteralPath $patchedJson -Encoding utf8
    My-Logger "Patched JSON saved to: $patchedJson"
    $JsonFile = $patchedJson
}

# ── Wait for VCF Installer API ────────────────────────────────────────────────
My-Logger "Waiting for VCF Installer API to be ready (timeout: $InstallerReadyTimeoutSec s) ..."
$elapsed = 0
while ($elapsed -lt $InstallerReadyTimeoutSec) {
    try {
        $resp = Invoke-WebRequest -Uri "https://${InstallerIP}/v1/system/appliance-info" `
            -Method GET -SkipCertificateCheck -TimeoutSec 5
        if ($resp.StatusCode -eq 200) {
            My-Logger "VCF Installer API is ready!" "cyan"
            break
        }
    } catch {}
    My-Logger "VCF Installer API not ready yet, waiting 120 s ..."
    Start-Sleep 120
    $elapsed += 120
}
if ($elapsed -ge $InstallerReadyTimeoutSec) {
    My-Logger "Timed out waiting for VCF Installer. Check VM at https://$InstallerIP" "red"
    exit 1
}

# ── Submit deployment JSON ────────────────────────────────────────────────────
My-Logger "Submitting deployment JSON to VCF Installer ..."
$headers  = Get-VCFInstallerToken
$jsonBody = Get-Content -Raw $JsonFile

try {
    $resp = Invoke-WebRequest -Uri "https://${InstallerIP}/v1/sddcs" `
        -Method POST -SkipCertificateCheck -TimeoutSec 30 `
        -Headers $headers -Body $jsonBody
    My-Logger "Deployment submitted! HTTP $($resp.StatusCode)" "cyan"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    My-Logger "Submission returned HTTP $statusCode" "yellow"
    My-Logger "Response: $($_.ErrorDetails.Message)" "yellow"
    if ($statusCode -notin 200,202) {
        My-Logger "Submission failed. Validate JSON manually at https://$InstallerIP/vcf-installer-ui/" "red"
        exit 1
    }
}

My-Logger "Monitor progress at: https://$InstallerIP/vcf-installer-ui/portal/progress-viewer" "cyan"

# ── Poll progress ─────────────────────────────────────────────────────────────
if ($MonitorProgress) {
    My-Logger "Polling deployment status every $PollIntervalSec s (Ctrl+C to stop polling and let it run) ..."
    $lastStatus = ""
    while ($true) {
        Start-Sleep $PollIntervalSec
        try {
            $headers = Get-VCFInstallerToken
            $resp    = Invoke-WebRequest -Uri "https://${InstallerIP}/v1/sddcs" `
                -Method GET -SkipCertificateCheck -TimeoutSec 10 -Headers $headers
            $data   = $resp.Content | ConvertFrom-Json
            # Handle both array and single-object responses
            $sddc   = if ($data -is [array]) { $data[0] } else { $data }
            $status = $sddc.status ?? $sddc.workflowStatus ?? "UNKNOWN"

            if ($status -ne $lastStatus) {
                My-Logger "Deployment status: $status" "yellow"
                $lastStatus = $status
            } else {
                My-Logger "Still $status ..."
            }

            if ($status -in "COMPLETED_WITH_SUCCESS","SUCCESS","COMPLETE") {
                My-Logger "=== VCF9 Bringup COMPLETED SUCCESSFULLY! ===" "cyan"
                break
            }
            if ($status -in "FAILED","COMPLETED_WITH_FAILURE","ERROR") {
                My-Logger "=== VCF9 Bringup FAILED. Check installer UI for details ===" "red"
                My-Logger "https://$InstallerIP/vcf-installer-ui/portal/progress-viewer" "red"
                break
            }
        } catch {
            My-Logger "Poll failed (installer might be busy): $_" "yellow"
        }
    }
}

$EndTime  = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes, 2)
My-Logger "vcf9-bringup.ps1 finished. Duration: $duration min"
