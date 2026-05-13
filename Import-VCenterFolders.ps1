# Import vCenter Folder Structure from CSV (exported by Export-VCenterFolders.ps1)

# ---- Target vCenter ----
$TargetVIServer   = "vcf-m01-vc01.home.lab"
$TargetVIUsername = "administrator@vsphere.local"
$TargetVIPassword = "VMware1!VMware1!"

# ---- Datacenter mapping ----
# If source and target datacenter names are the same, leave as @{}
# If they differ, add entries: @{ "SourceDC" = "TargetDC" }
$DatacenterMap = @{
    "Datacenter" = "vcf-m01-dc"
}

# ---- Input file ----
$InputCSV = "vcenter-folders.csv"

# ---- Options ----
$WhatIf = $false   # $true = simulate only, no folders will be created

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "import-vcenter-folders.log"

# Script-scope counters (accumulated across all datacenters)
$script:CountCreated = 0
$script:CountExisted = 0
$script:CountWhatIf  = 0
$script:CountErrored = 0

# Script-scope folder cache (reset per datacenter, counters persist)
$script:FolderCache = @{}
# Tracks virtual paths created in WhatIf mode so child folders can still be simulated
$script:WhatIfPaths = [System.Collections.Generic.HashSet[string]]::new()

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )
    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"
    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    "[$timeStamp] $message" | Out-File -Append -LiteralPath $verboseLogFile
}

# Sort folder list by depth so parent folders are always processed before children
Function Sort-ByDepth {
    param($FolderList)
    $FolderList | Sort-Object { ($_.FolderPath -split "/").Count }, FolderPath
}

Function Get-OrCreate-Folder {
    param(
        [Parameter(Mandatory=$true)][string]$FolderPath,
        [Parameter(Mandatory=$true)]$Datacenter,
        [Parameter(Mandatory=$true)]$Connection
    )

    # Full path already in cache — return immediately
    if ($script:FolderCache.ContainsKey($FolderPath)) {
        return $script:FolderCache[$FolderPath]
    }

    # Locate the hidden "vm" root folder under the datacenter
    $rootFolder = Get-Folder -Server $Connection -Name "vm" -Location $Datacenter -Type VM `
                      -ErrorAction SilentlyContinue |
                  Where-Object { $_.Parent.Name -eq $Datacenter.Name } |
                  Select-Object -First 1

    if (-not $rootFolder) {
        My-Logger "  ERROR: Cannot find root VM folder under datacenter '$($Datacenter.Name)'" "red"
        return $null
    }

    $currentFolder = $rootFolder
    $builtPath     = ""

    foreach ($part in ($FolderPath -split "/")) {
        $builtPath = if ($builtPath) { "$builtPath/$part" } else { $part }

        # This level is already cached — use it without incrementing counters
        if ($script:FolderCache.ContainsKey($builtPath)) {
            $currentFolder = $script:FolderCache[$builtPath]
            continue
        }

        # If the parent path is a WhatIf virtual path, skip the Get-Folder call
        # (the parent folder doesn't actually exist in vCenter yet)
        $parentPath      = if ($builtPath -match "/") { $builtPath -replace "/[^/]+$","" } else { "" }
        $parentIsVirtual = $parentPath -ne "" -and $script:WhatIfPaths.Contains($parentPath)

        $existing = $null
        if (-not $parentIsVirtual) {
            $existing = Get-Folder -Server $Connection -Name $part -Location $currentFolder `
                            -Type VM -NoRecursion -ErrorAction SilentlyContinue |
                        Select-Object -First 1
        }

        if ($existing) {
            # Folder already exists
            My-Logger "  [EXISTS]  /$builtPath" "yellow"
            $script:FolderCache[$builtPath] = $existing
            $script:CountExisted++
            $currentFolder = $existing

        } elseif ($WhatIf) {
            # WhatIf mode: record path as virtual so child levels can still be simulated
            My-Logger "  [WHATIF]  Would create: /$builtPath" "cyan"
            $script:WhatIfPaths.Add($builtPath) | Out-Null
            $script:FolderCache[$builtPath] = "[WHATIF]"   # sentinel value
            $script:CountWhatIf++
            $currentFolder = "[WHATIF]"                    # sentinel; next level detects parentIsVirtual

        } else {
            # Create the folder
            My-Logger "  [CREATE]  /$builtPath" "green"
            $newFolder = New-Folder -Name $part -Server $Connection -Location $currentFolder
            $script:FolderCache[$builtPath] = $newFolder
            $script:CountCreated++
            $currentFolder = $newFolder
        }
    }

    return $currentFolder
}

# ---- Pre-flight checks ----
if (-not (Test-Path $InputCSV)) {
    Write-Host -ForegroundColor Red "Cannot find input file: $InputCSV"
    exit 1
}
if ($PSVersionTable.PSEdition -ne "Core") {
    Write-Host -ForegroundColor Red "PowerShell Core was not detected, please install before continuing."
    exit 1
}

# ---- Load CSV ----
My-Logger "Reading $InputCSV ..."
$allFolders = Import-Csv -Path $InputCSV -Encoding UTF8

if (-not $allFolders -or @($allFolders).Count -eq 0) {
    Write-Host -ForegroundColor Red "CSV is empty or invalid."
    exit 1
}
My-Logger "Loaded $(@($allFolders).Count) folder entries."

# ---- Connect to target vCenter ----
My-Logger "Connecting to Target vCenter $TargetVIServer ..."
$viConnection = Connect-VIServer $TargetVIServer -User $TargetVIUsername -Password $TargetVIPassword -WarningAction SilentlyContinue

if (-not $viConnection) {
    Write-Host -ForegroundColor Red "Failed to connect to $TargetVIServer"
    exit 1
}

# ---- Pre-run summary ----
$dcGroups = $allFolders | Group-Object Datacenter
Write-Host -ForegroundColor Magenta "`nImport Summary:"
Write-Host -ForegroundColor Yellow "  Target vCenter : $TargetVIServer"
Write-Host -ForegroundColor Yellow "  Input CSV      : $InputCSV"
Write-Host -ForegroundColor Yellow "  Total folders  : $(@($allFolders).Count)"
Write-Host -ForegroundColor Yellow "  WhatIf mode    : $WhatIf"
Write-Host -ForegroundColor Yellow "  Datacenters    :"
foreach ($g in $dcGroups) {
    $targetDC = if ($DatacenterMap.ContainsKey($g.Name)) { $DatacenterMap[$g.Name] } else { $g.Name }
    Write-Host -ForegroundColor White "    $($g.Name) -> $targetDC  ($($g.Count) folders)"
}
Write-Host ""

$answer = Read-Host "Proceed? (Y/N)"
if ($answer -ne "Y" -and $answer -ne "y") {
    Disconnect-VIServer -Server $viConnection -Confirm:$false
    exit 0
}

# ---- Process each datacenter ----
foreach ($group in $dcGroups) {
    $sourceDCName = $group.Name
    $targetDCName = if ($DatacenterMap.ContainsKey($sourceDCName)) { $DatacenterMap[$sourceDCName] } else { $sourceDCName }

    My-Logger "Processing Datacenter: $sourceDCName -> $targetDCName" "cyan"

    $targetDC = Get-Datacenter -Server $viConnection -Name $targetDCName -ErrorAction SilentlyContinue
    if (-not $targetDC) {
        My-Logger "  ERROR: Datacenter '$targetDCName' not found on $TargetVIServer. Skipping $($group.Count) folder(s)." "red"
        $script:CountErrored += $group.Count
        continue
    }

    # Reset cache per datacenter (counters accumulate across all datacenters)
    $script:FolderCache = @{}
    $script:WhatIfPaths = [System.Collections.Generic.HashSet[string]]::new()

    # Sort by depth so parent folders are created before their children
    $sortedFolders = Sort-ByDepth -FolderList $group.Group

    foreach ($entry in $sortedFolders) {
        $result = Get-OrCreate-Folder `
                    -FolderPath $entry.FolderPath `
                    -Datacenter $targetDC `
                    -Connection $viConnection

        if ($null -eq $result) {
            $script:CountErrored++
        }
    }
}

# ---- Disconnect ----
My-Logger "Disconnecting from $TargetVIServer ..."
Disconnect-VIServer -Server $viConnection -Confirm:$false

# ---- Results ----
My-Logger "======================================================" "yellow"
if ($WhatIf) {
    My-Logger "WhatIf simulation complete (no changes made)" "cyan"
    My-Logger "Would create : $($script:CountWhatIf)" "cyan"
    My-Logger "Already exist: $($script:CountExisted)" "yellow"
} else {
    My-Logger "Import Complete!" "yellow"
    My-Logger "Created      : $($script:CountCreated)" "yellow"
    My-Logger "Already exist: $($script:CountExisted)" "yellow"
}
if ($script:CountErrored -gt 0) {
    My-Logger "Errors       : $($script:CountErrored)" "red"
}
My-Logger "Log          : $verboseLogFile" "yellow"
My-Logger "======================================================" "yellow"
