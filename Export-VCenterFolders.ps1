# Export vCenter Folder Structure to CSV and JSON
# Reference: autodeployvcf9m01.ps1

$VIServer   = "labvc.lab.com"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "VMware1!"

$OutputCSV  = "vcenter-folders.csv"
$OutputJSON = "vcenter-folders.json"

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "export-vcenter-folders.log"

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

# Traverse parent chain until hitting the hidden "vm" root folder under datacenter.
# Works for any depth (3-4+ levels) without relying on type checks.
Function Get-FolderPath {
    param([Parameter(Mandatory=$true)]$Folder)

    $parts = @()
    $cur   = $Folder

    while ($cur -and $cur.Name -ne "vm") {
        $parts = @($cur.Name) + $parts
        $cur   = $cur.Parent
    }

    return ($parts -join "/")
}

if ($PSVersionTable.PSEdition -ne "Core") {
    Write-Host -ForegroundColor Red "PowerShell Core was not detected, please install before continuing."
    exit 1
}

My-Logger "Connecting to vCenter Server $VIServer ..."
$viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

if (-not $viConnection) {
    Write-Host -ForegroundColor Red "Failed to connect to $VIServer"
    exit 1
}

My-Logger "Retrieving all Datacenters ..."
$datacenters = Get-Datacenter -Server $viConnection

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($dc in $datacenters) {
    My-Logger "Processing Datacenter: $($dc.Name)" "cyan"

    # Get-Folder returns ALL VM folders recursively under the datacenter.
    # Filter out the hidden "vm" root folder that vSphere creates automatically.
    $folders = Get-Folder -Server $viConnection -Location $dc -Type VM |
               Where-Object { $_.Name -ne "vm" }

    foreach ($folder in $folders | Sort-Object { ($_.Name) }) {
        $folderPath = Get-FolderPath -Folder $folder
        $depth      = ($folderPath -split "/").Count

        # VMs directly in this folder only (not in subfolders)
        $vms      = Get-VM -Server $viConnection -Location $folder -NoRecursion -ErrorAction SilentlyContinue
        $vmNames  = ($vms | Sort-Object Name | Select-Object -ExpandProperty Name) -join ";"
        $vmCount  = if ($vms) { @($vms).Count } else { 0 }

        # Direct child folder count
        $childFolders = Get-Folder -Server $viConnection -Location $folder -NoRecursion -Type VM -ErrorAction SilentlyContinue
        $childCount   = if ($childFolders) { @($childFolders).Count } else { 0 }

        $parentName = if ($folder.Parent.Name -ne "vm") { $folder.Parent.Name } else { "(root)" }

        $obj = [PSCustomObject]@{
            Datacenter   = $dc.Name
            FolderName   = $folder.Name
            FolderPath   = $folderPath
            Depth        = $depth
            ParentFolder = $parentName
            ChildFolders = $childCount
            VMCount      = $vmCount
            VMNames      = $vmNames
            FolderID     = $folder.Id
        }

        $results.Add($obj)
        My-Logger "  [D$depth] /$folderPath  ($vmCount VMs, $childCount subfolders)"
    }
}

# Export CSV
My-Logger "Exporting CSV to $OutputCSV ..."
$results | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

# Export JSON (tree structure per datacenter)
My-Logger "Exporting JSON to $OutputJSON ..."

$tree = foreach ($dc in ($results | Select-Object -ExpandProperty Datacenter -Unique)) {
    $dcFolders = $results | Where-Object { $_.Datacenter -eq $dc }
    [PSCustomObject]@{
        datacenter = $dc
        folders    = @($dcFolders | ForEach-Object {
            [PSCustomObject]@{
                name         = $_.FolderName
                path         = $_.FolderPath
                depth        = $_.Depth
                parent       = $_.ParentFolder
                childFolders = $_.ChildFolders
                vmCount      = $_.VMCount
                vms          = if ($_.VMNames) { $_.VMNames -split ";" } else { @() }
            }
        })
    }
}

$tree | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $OutputJSON -Encoding UTF8

My-Logger "Disconnecting from $VIServer ..."
Disconnect-VIServer -Server $viConnection -Confirm:$false

My-Logger "======================================================" "yellow"
My-Logger "Export Complete!" "yellow"
My-Logger "Total folders exported : $($results.Count)" "yellow"
My-Logger "CSV  output            : $OutputCSV" "yellow"
My-Logger "JSON output            : $OutputJSON" "yellow"
My-Logger "======================================================" "yellow"
