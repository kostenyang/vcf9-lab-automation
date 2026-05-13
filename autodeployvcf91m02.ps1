# Author: Based on William Lam's vcf-fleet-automated-lab-deployment
# Adapted from autodeployvcf9m02.ps1 — Target: VCF 9.1 via 9.0.2 + LCM upgrade
#
# Deployment path:
#   1. This script deploys Nested ESXi (9.0.2) + VCF Installer (SDDC Mgr 9.0.2) for M02
#   2. Run vcf9-bringup.ps1 to bring up VCF 9.0.2 on M02 (10.0.1.14–17, SDDC .18)
#   3. Use SDDC Manager LCM with the 9.1 bundle (E:\9.1\VCF-SDDC-Manager-
#      Appliance-9.1.0.0.25371088.ova) to upgrade to 9.1
#
# IP usage: same as M02 (10.0.1.14–17, SDDC 10.0.1.18) — replaces the M02 deployment.
# DNS / Nested ESXi VLAN / Trunk-Nobinding portgroup must already exist.

# vCenter Server used to deploy VMware Cloud Foundation Lab
$VIServer   = "10.0.0.101"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "VMware1!"

# Full Path to Nested ESXi 9.0.2 & VCF Installer (SDDC Mgr 9.0.2) OVA
$NestedESXiApplianceOVA = "E:\Nested_ESXi9.0.2_Appliance_Template_v1.0.ova"
$VCFInstallerOVA        = "E:\VCF-SDDC-Manager-Appliance-9.0.2.0.25151285.ova"

# General Deployment Configuration
$VMDatacenter = "Datacenter"
$VMCluster    = "Cluster"
$VMNetwork    = "Trunk-Nobinding"
$VMDatastore  = "vsanDatastore"
$VMNetmask    = "255.255.254.0"
$VMGateway    = "10.0.0.1"
$VMDNS        = "10.0.0.200"
$VMNTP        = "10.0.1.254"
$VMPassword   = "VMware1!VMware1!"
$VMDomain     = "home.lab"
$VMSyslog     = "10.0.0.123"
$VMFolder     = "VCF"

# VCF Installer VM (取代 VCF 5.x 的 Cloud Builder)
$VCFInstallerVMName        = "vcf-m02-inst01"
$VCFInstallerFQDN          = "vcf-m02-inst01.$VMDomain"
$VCFInstallerIP            = "10.0.1.4"
$VCFInstallerAdminUsername = "admin@local"
$VCFInstallerAdminPassword = "VMw@re123!PSO777"
$VCFInstallerRootPassword  = "VMw@re123!PSO777"

# VCF Instance Configuration
$VCFInstanceName   = "vcf-m02"
$VCFManagementPool = "vcf-m02-cl01-np01"
$CEIPEnabled       = $false
$VSANESAEnabled    = $false   # set $true if using vSAN ESA

# SDDC Manager Configuration
$SddcManagerHostname      = "vcf-m02-sddcm01"
$SddcManagerIP            = "10.0.1.18"
$SddcManagerRootPassword  = "VMware1!VMware1!"
$SddcManagerSSHPassword   = "VMware1!VMware1!"
$SddcManagerLocalPassword = "VMware1!VMware1!"

# Nested ESXi VMs for Management Domain (M02)
$NestedESXiHostnameToIPs = @{
    "vcf-m02-esx01" = "10.0.1.14"
    "vcf-m02-esx02" = "10.0.1.15"
    "vcf-m02-esx03" = "10.0.1.16"
    "vcf-m02-esx04" = "10.0.1.17"
}

# Nested ESXi VM Resources
$NestedESXivCPU          = "24"
$NestedESXivMEM          = "256" # GB
$NestedESXiCachingvDisk  = "100" # GB
$NestedESXiCapacityvDisk = "1000" # GB

# vCenter Configuration
$VCSAName           = "vcf-m02-vc01"
$VCSAIP             = "10.0.1.19"
$VCSARootPassword   = "VMware1!PSO"
$VCSASSOPassword    = "VMware1!PSO"
$VCSASize           = "small"    # tiny / small / medium / large / xlarge
$VCSADatacenterName = "vcf-m02-dc01"
$VCSAClusterName    = "vcf-m02-cl01"

# vSAN Configuration
$VSANDatastoreName = "vcf-m02-cl01-ds-vsan01"
$VSANESAEnabled    = $false

# VDS Configuration
$VDSName = "vcf-m02-cl01-vds01"

# NSX Configuration
$NSXManagerSize         = "medium"
$NSXManagerVIPHostname  = "vcf-m02-nsx01"
$NSXManagerVIPIP        = "10.0.1.21"
$NSXManagerNodeHostname = "vcf-m02-nsx01a"
$NSXManagerNodeIP       = "10.0.1.20"
$NSXTransportVlanId     = 0       # 0 = 無 VLAN tag
$NSXRootPassword        = "VMware1!VMware1!"
$NSXAdminPassword       = "VMware1!VMware1!"
$NSXAuditPassword       = "VMware1!VMware1!"

# NSX TEP (Tunnel Endpoint) IP Pool
$NSXTEPPoolName = "nsx-vtep-m02"
$NSXTEPPoolDesc = "NSX TEP Pool for vcf-m02"
$NSXTEPSubnet   = "192.168.29.0/24"
$NSXTEPGateway  = "192.168.29.254"
$NSXTEPStartIP  = "192.168.29.9"
$NSXTEPEndIP    = "192.168.29.24"

# Network CIDRs for M02
$MgmtNetworkCidr    = "10.0.0.0/23"
$vMotionNetworkCidr = "192.168.23.0/24"
$vMotionGateway     = "192.168.23.254"
$vMotionVlanId      = 13
$vMotionStartIP     = "192.168.23.9"
$vMotionEndIP       = "192.168.23.12"
$vSANNetworkCidr    = "192.168.24.0/24"
$vSANGateway        = "192.168.24.254"
$vSANVlanId         = 14
$vSANStartIP        = "192.168.24.9"
$vSANEndIP          = "192.168.24.12"

# VCF Operations Configuration
$VCFOpsHostname      = "vcf-m02-ops01.$VMDomain"
$VCFOpsSize          = "small"    # small / medium / large
$VCFOpsIP            = "10.0.1.22"
$VCFOpsRootPassword  = "VMware1!VMware1!"
$VCFOpsAdminPassword = "VMware1!VMware1!"

# VCF Operations Fleet Manager
$VCFFleetHostname      = "vcf-m02-fleet01.$VMDomain"
$VCFFleetIP            = "10.0.1.23"
$VCFFleetRootPassword  = "VMware1!VMware1!"
$VCFFleetAdminPassword = "VMware1!VMware1!"

# VCF Operations Collector
$VCFCollectorHostname     = "vcf-m02-opsc01.$VMDomain"
$VCFCollectorIP           = "10.0.1.24"
$VCFCollectorSize         = "small"
$VCFCollectorRootPassword = "VMware1!VMware1!"

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vcf9-m02-deployment.log"
$random_string  = -join ((65..90) + (97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$VAppName       = "Nested-VCF9-M02-$random_string"

$preCheck            = 1
$confirmDeployment   = 1
$deployNestedESXiVMs = 1
$deployVCFInstaller  = 1
$moveVMsIntovApp     = 1
$generateJson        = 1

$StartTime = Get-Date

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )
    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"
    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

# ─────────────────────────────────────────────
# PRE-CHECK
# ─────────────────────────────────────────────
if($preCheck -eq 1) {
    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`n"
        exit
    }
    if(!(Test-Path $VCFInstallerOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCFInstallerOVA ...`n"
        exit
    }
    if($PSVersionTable.PSEdition -ne "Core") {
        Write-Host -ForegroundColor Red "`tPowerShell Core was not detected, please install that before continuing ...`n"
        exit
    }
}

# ─────────────────────────────────────────────
# CONFIRM DEPLOYMENT
# ─────────────────────────────────────────────
if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- VCF 9 Automated Lab Deployment Configuration (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "Nested ESXi OVA: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "VCF Installer OVA: "
    Write-Host -ForegroundColor White $VCFInstallerOVA

    Write-Host -ForegroundColor Yellow "`n---- vCenter Server Deployment Target ----"
    Write-Host -NoNewline -ForegroundColor Green "vCenter Server: "
    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork
    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore
    Write-Host -NoNewline -ForegroundColor Green "VM Cluster: "
    Write-Host -ForegroundColor White $VMCluster
    Write-Host -NoNewline -ForegroundColor Green "vApp: "
    Write-Host -ForegroundColor White $VAppName

    Write-Host -ForegroundColor Yellow "`n---- VCF Installer (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "FQDN: "
    Write-Host -ForegroundColor White $VCFInstallerFQDN
    Write-Host -NoNewline -ForegroundColor Green "IP: "
    Write-Host -ForegroundColor White $VCFInstallerIP

    Write-Host -ForegroundColor Yellow "`n---- SDDC Manager (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White "$SddcManagerHostname.$VMDomain"
    Write-Host -NoNewline -ForegroundColor Green "IP: "
    Write-Host -ForegroundColor White $SddcManagerIP

    Write-Host -ForegroundColor Yellow "`n---- Nested ESXi VMs (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "Count: "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.count
    Write-Host -NoNewline -ForegroundColor Green "vCPU: "
    Write-Host -ForegroundColor White $NestedESXivCPU
    Write-Host -NoNewline -ForegroundColor Green "vMEM: "
    Write-Host -ForegroundColor White "$NestedESXivMEM GB"
    Write-Host -NoNewline -ForegroundColor Green "Cache VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCachingvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "Capacity VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCapacityvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "IPs: "
    Write-Host -ForegroundColor White ($NestedESXiHostnameToIPs.Values -join ", ")
    Write-Host -NoNewline -ForegroundColor Green "Netmask: "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    Write-Host -NoNewline -ForegroundColor Green "DNS: "
    Write-Host -ForegroundColor White $VMDNS
    Write-Host -NoNewline -ForegroundColor Green "NTP: "
    Write-Host -ForegroundColor White $VMNTP

    Write-Host -ForegroundColor Yellow "`n---- vCenter (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White "$VCSAName.$VMDomain"
    Write-Host -NoNewline -ForegroundColor Green "IP: "
    Write-Host -ForegroundColor White $VCSAIP

    Write-Host -ForegroundColor Yellow "`n---- NSX Manager (M02) ----"
    Write-Host -NoNewline -ForegroundColor Green "VIP Hostname: "
    Write-Host -ForegroundColor White "$NSXManagerVIPHostname.$VMDomain"
    Write-Host -NoNewline -ForegroundColor Green "VIP IP: "
    Write-Host -ForegroundColor White $NSXManagerVIPIP
    Write-Host -NoNewline -ForegroundColor Green "Node1 Hostname: "
    Write-Host -ForegroundColor White "$NSXManagerNodeHostname.$VMDomain"
    Write-Host -NoNewline -ForegroundColor Green "Node1 IP: "
    Write-Host -ForegroundColor White $NSXManagerNodeIP

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -and $answer -ne "y") {
        exit
    }
    Clear-Host
}

# ─────────────────────────────────────────────
# CONNECT TO vCENTER
# ─────────────────────────────────────────────
if($deployNestedESXiVMs -eq 1 -or $deployVCFInstaller -eq 1) {
    My-Logger "Connecting to Management vCenter Server $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select-Object -First 1
    $cluster   = Get-Cluster  -Server $viConnection -Name $VMCluster
    $vmhost    = $cluster | Get-VMHost | Select-Object -First 1
}

# ─────────────────────────────────────────────
# DEPLOY NESTED ESXi VMs
# ─────────────────────────────────────────────
if($deployNestedESXiVMs -eq 1) {
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName      = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
        $ovfconfig.NetworkMapping.$networkMapLabel.value   = $VMNetwork
        $ovfconfig.common.guestinfo.hostname.value         = "${VMName}.${VMDomain}"
        $ovfconfig.common.guestinfo.ipaddress.value        = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value          = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value          = $VMGateway
        $ovfconfig.common.guestinfo.dns.value              = $VMDNS
        $ovfconfig.common.guestinfo.domain.value           = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value              = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value           = $VMSyslog
        $ovfconfig.common.guestinfo.password.value         = $VMPassword
        $ovfconfig.common.guestinfo.ssh.value              = $true

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

        My-Logger "Adding vmnic2/vmnic3 to $VMName ..."
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet2.filter4.name"      -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet2.filter4.onFailure" -value "failOpen"          -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -name "ethernet3.filter4.name"      -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet3.filter4.onFailure" -value "failOpen"          -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vCPU to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vSAN Cache VMDK to $NestedESXiCachingvDisk GB & Capacity VMDK to $NestedESXiCapacityvDisk GB ..."
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiCachingvDisk  -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Powering On $VMName ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

# ─────────────────────────────────────────────
# DEPLOY VCF INSTALLER VM
# ─────────────────────────────────────────────
if($deployVCFInstaller -eq 1) {
    $ovfconfig = Get-OvfConfiguration $VCFInstallerOVA

    $networkMapLabel = ($ovfconfig.ToHashTable().keys | Where-Object {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
    $ovfconfig.NetworkMapping.$networkMapLabel.value       = $VMNetwork
    $ovfconfig.Common.vami.hostname.value                  = $VCFInstallerFQDN
    $ovfconfig.vami.SDDC_Manager.ip0.value                 = $VCFInstallerIP
    $ovfconfig.vami.SDDC_Manager.netmask0.value            = $VMNetmask
    $ovfconfig.vami.SDDC_Manager.gateway.value             = $VMGateway
    $ovfconfig.vami.SDDC_Manager.DNS.value                 = $VMDNS
    $ovfconfig.vami.SDDC_Manager.domain.value              = $VMDomain
    $ovfconfig.vami.SDDC_Manager.searchpath.value          = $VMDomain
    $ovfconfig.common.guestinfo.ntp.value                  = $VMNTP
    $ovfconfig.Common.LOCAL_USER_PASSWORD.value            = $VCFInstallerAdminPassword
    $ovfconfig.Common.ROOT_PASSWORD.value                  = $VCFInstallerRootPassword

    My-Logger "Deploying VCF Installer VM $VCFInstallerVMName ..."
    $vm = Import-VApp -Source $VCFInstallerOVA -OvfConfiguration $ovfconfig -Name $VCFInstallerVMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

    My-Logger "Powering On $VCFInstallerVMName ..."
    $vm | Start-Vm -RunAsync | Out-Null
}

# ─────────────────────────────────────────────
# MOVE VMs INTO vAPP
# ─────────────────────────────────────────────
if($moveVMsIntovApp -eq 1) {
    My-Logger "Creating vApp $VAppName ..."
    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

    if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
        My-Logger "Creating VM Folder $VMFolder ..."
        New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm) | Out-Null
    }

    if($deployNestedESXiVMs -eq 1) {
        My-Logger "Moving Nested ESXi VMs into $VAppName vApp ..."
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $vm = Get-VM -Name $_.Key -Server $viConnection
            Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployVCFInstaller -eq 1) {
        $installerVM = Get-VM -Name $VCFInstallerVMName -Server $viConnection
        My-Logger "Moving $VCFInstallerVMName into $VAppName vApp ..."
        Move-VM -VM $installerVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    My-Logger "Moving $VAppName to VM Folder $VMFolder ..."
    Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile
}

# ─────────────────────────────────────────────
# DISCONNECT
# ─────────────────────────────────────────────
if($deployNestedESXiVMs -eq 1 -or $deployVCFInstaller -eq 1) {
    My-Logger "Disconnecting from $VIServer ..."
    Disconnect-VIServer -Server $viConnection -Confirm:$false
}

# ─────────────────────────────────────────────
# GENERATE VCF 9 JSON DEPLOYMENT CONFIG
# ─────────────────────────────────────────────
if($generateJson -eq 1) {

    # Build hostSpecs JSON
    $hostSpecsJson = ""
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $hostSpecsJson += @"
    {"hostname":"${VMName}.${VMDomain}","credentials":{"username":"root","password":"${VMPassword}"},"sslThumbprint":"REPLACE_WITH_ACTUAL_THUMBPRINT"},
"@
    }
    # Remove trailing comma from last entry
    $hostSpecsJson = $hostSpecsJson -replace ",\s*$", ""

    $vsanESAJson = if($VSANESAEnabled) { '"esaConfig":{"enabled":true}' } else { '"esaConfig":{"enabled":false}' }

    $vcfConfig = @"
{
  "vcfInstanceName": "$VCFInstanceName",
  "managementPoolName": "$VCFManagementPool",
  "ceipEnabled": $($CEIPEnabled.ToString().ToLower()),
  "version": "9.0.0.0",
  "dnsSpec": {
    "subdomain": "$VMDomain",
    "nameservers": ["$VMDNS"]
  },
  "ntpServers": ["$VMNTP"],
  "hostSpecs": [
$hostSpecsJson
  ],
  "vcenterSpec": {
    "vcenterHostname": "${VCSAName}.${VMDomain}",
    "vcenterIp": "$VCSAIP",
    "rootVcenterPassword": "$VCSARootPassword",
    "vmSize": "$VCSASize",
    "ssoDomain": "vsphere.local",
    "adminUserSsoPassword": "$VCSASSOPassword",
    "useExistingDeployment": false,
    "datacenterName": "$VCSADatacenterName",
    "clusterName": "$VCSAClusterName"
  },
  "clusterSpec": {
    "datacenterName": "$VCSADatacenterName",
    "clusterName": "$VCSAClusterName"
  },
  "dvsSpecs": [
    {
      "dvsName": "$VDSName",
      "networks": ["MANAGEMENT","VM_MANAGEMENT","VMOTION","VSAN"],
      "mtu": 9000,
      "nsxtSwitchConfig": {
        "transportZones": [
          {"name": "VCF-Created-Overlay-Zone","transportType": "OVERLAY"}
        ]
      },
      "vmnicsToUplinks": [
        {"id": "vmnic0","uplink": "uplink1"},
        {"id": "vmnic1","uplink": "uplink2"}
      ],
      "nsxTeamings": [
        {"policy": "LOADBALANCE_SRCID","activeUplinks": ["uplink1","uplink2"]}
      ]
    }
  ],
  "networkSpecs": [
    {
      "networkType": "MANAGEMENT",
      "subnet": "$MgmtNetworkCidr",
      "gateway": "$VMGateway",
      "vlanId": 0,
      "mtu": 1500,
      "teamingPolicy": "loadbalance_loadbased",
      "activeUplinks": ["uplink1","uplink2"],
      "portGroupKey": "${VDSName}-pg-esx-mgmt"
    },
    {
      "networkType": "VM_MANAGEMENT",
      "subnet": "$MgmtNetworkCidr",
      "gateway": "$VMGateway",
      "vlanId": 0,
      "mtu": 1500,
      "teamingPolicy": "loadbalance_loadbased",
      "activeUplinks": ["uplink1","uplink2"],
      "portGroupKey": "${VDSName}-pg-vm-mgmt"
    },
    {
      "networkType": "VMOTION",
      "subnet": "$vMotionNetworkCidr",
      "gateway": "$vMotionGateway",
      "includeIpAddressRanges": [{"startIpAddress": "$vMotionStartIP","endIpAddress": "$vMotionEndIP"}],
      "vlanId": $vMotionVlanId,
      "mtu": 9000,
      "teamingPolicy": "loadbalance_loadbased",
      "activeUplinks": ["uplink1","uplink2"],
      "portGroupKey": "${VDSName}-pg-vmotion"
    },
    {
      "networkType": "VSAN",
      "subnet": "$vSANNetworkCidr",
      "gateway": "$vSANGateway",
      "includeIpAddressRanges": [{"startIpAddress": "$vSANStartIP","endIpAddress": "$vSANEndIP"}],
      "vlanId": $vSANVlanId,
      "mtu": 9000,
      "teamingPolicy": "loadbalance_loadbased",
      "activeUplinks": ["uplink1","uplink2"],
      "portGroupKey": "${VDSName}-pg-vsan"
    }
  ],
  "nsxtSpec": {
    "nsxtManagers": [
      {"hostname": "${NSXManagerNodeHostname}.${VMDomain}"}
    ],
    "nsxtManagerSize": "$NSXManagerSize",
    "vipFqdn": "${NSXManagerVIPHostname}.${VMDomain}",
    "rootNsxtManagerPassword": "$NSXRootPassword",
    "nsxtAdminPassword": "$NSXAdminPassword",
    "nsxtAuditPassword": "$NSXAuditPassword",
    "transportVlanId": $NSXTransportVlanId,
    "ipAddressPoolSpec": {
      "name": "$NSXTEPPoolName",
      "description": "$NSXTEPPoolDesc",
      "subnets": [
        {
          "ipAddressPoolRanges": [{"start": "$NSXTEPStartIP","end": "$NSXTEPEndIP"}],
          "cidr": "$NSXTEPSubnet",
          "gateway": "$NSXTEPGateway"
        }
      ]
    },
    "skipNsxOverlayOverManagementNetwork": true,
    "useExistingDeployment": false
  },
  "datastoreSpec": {
    "vsanSpec": {
      "datastoreName": "$VSANDatastoreName",
      $vsanESAJson
    }
  },
  "sddcManagerSpec": {
    "hostname": "${SddcManagerHostname}.${VMDomain}",
    "rootPassword": "$SddcManagerRootPassword",
    "sshPassword": "$SddcManagerSSHPassword",
    "localUserPassword": "$SddcManagerLocalPassword",
    "useExistingDeployment": false
  },
  "vcfOperationsSpec": {
    "nodes": [{"hostname": "$VCFOpsHostname","rootUserPassword": "$VCFOpsRootPassword","type": "master"}],
    "adminUserPassword": "$VCFOpsAdminPassword",
    "applianceSize": "$VCFOpsSize",
    "useExistingDeployment": false
  },
  "vcfOperationsFleetManagementSpec": {
    "hostname": "$VCFFleetHostname",
    "rootUserPassword": "$VCFFleetRootPassword",
    "adminUserPassword": "$VCFFleetAdminPassword",
    "useExistingDeployment": false
  },
  "vcfOperationsCollectorSpec": {
    "hostname": "$VCFCollectorHostname",
    "rootUserPassword": "$VCFCollectorRootPassword",
    "applianceSize": "$VCFCollectorSize",
    "useExistingDeployment": false
  }
}
"@

    My-Logger "Generating VCF 9 Installer deployment config: vcf9-m02-config.json"
    $vcfConfig | Out-File -LiteralPath vcf9-m02-config.json -Encoding utf8

    My-Logger "======================================================" "yellow"
    My-Logger "NEXT STEPS:" "yellow"
    My-Logger "1. Wait for VCF Installer VM to boot (~5-10 min)" "yellow"
    My-Logger "2. Open browser: https://$VCFInstallerIP" "yellow"
    My-Logger "3. Login: $VCFInstallerAdminUsername" "yellow"
    My-Logger "4. Upload vcf9-m02-config.json or use the wizard" "yellow"
    My-Logger "5. Fill in sslThumbprint for each ESXi host" "yellow"
    My-Logger "======================================================" "yellow"
}

$EndTime  = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "VCF 9 M02 Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration mins"