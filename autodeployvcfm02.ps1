# Author: William Lam
# Website: www.williamlam.com

# vCenter Server used to deploy VMware Cloud Foundation Lab
$VIServer = "10.0.0.101"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "VMware1!"

# Full Path to both the Nested ESXi 7.0u1d & Cloud Builder oVA
$NestedESXiApplianceOVA = "C:\Users\Administrator\OneDrive\桌面\VCF\Nested_ESXi8.0u3b_Appliance_Template_v1.ova"
$CloudBuilderOVA = "C:\Users\Administrator\OneDrive\桌面\VCF\VMware-Cloud-Builder-5.2.1.0-24307856_OVF10.ova"

# VCF Required Licenses
$VCSALicense = "104HH-D4343-07879-MV08K-2D2H2"
$ESXILicense = "JJ2WR-25L9P-H71A8-6J20P-C0K3F"
$VSANLicense = "HN0D8-AAJ1Q-07D00-6U924-CX224"
$NSXLicense = "5M214-JN34K-F81D4-0D384-3DV6N"

# Cloud Builder Configurations
$CloudbuilderVMName = "vcf-m01-cb01"
$CloudbuilderHostname = "vcf-m01-cb01.home.lab"
$CloudbuilderIP = "10.0.1.4"
$CloudbuilderAdminUsername = "admin"
$CloudbuilderAdminPassword = "VMw@re123!PSO777"
$CloudbuilderRootPassword = "VMw@re123!PSO777"

# SDDC Manager Configuration
$SddcManagerName = "vcf-m02-sddcm01"
$SddcManagerIP = "10.0.1.5"
$SddcManagerVcfPassword = "VMware1!VMware1!"
$SddcManagerRootPassword = "VMware1!VMware1!"
$SddcManagerRestPassword = "VMware1!VMware1!"
$SddcManagerLocalPassword = "VMware1!VMware1!"

# Nested ESXi VMs to deploy
$NestedESXiHostnameToIPs = @{
    "vcf-m02-esx01"   = "10.0.1.14"
    "vcf-m02-esx02"   = "10.0.1.15"
    "vcf-m02-esx03"   = "10.0.1.16"
    "vcf-m02-esx04"   = "10.0.1.17"
}

# Nested ESXi VM Resources
$NestedESXivCPU = "12"
$NestedESXivMEM = "120" #GB
$NestedESXiCachingvDisk = "100" #GB
$NestedESXiCapacityvDisk = "700" #GB

# ESXi Configuration
$NestedESXiManagementNetworkCidr = "10.0.0.0/23" # should match $VMNetwork configuration

# vCenter Configuration
$VCSAName = "vcf-m02-vc01"
$VCSAIP = "10.0.1.19"
$VCSARootPassword = "VMware1!PSO"
$VCSASSOPassword = "VMware1!PSO"

# NSX Configuration
$NSXManagerVIPName = "vcf-m02-nsx01"
$NSXManagerVIPIP = "10.0.1.21"
$NSXManagerNode1Name = "vcf-m02-nsx01a"
$NSXManagerNode1IP = "10.0.1.20"
$NSXRootPassword = "VMware1!VMware1!"
$NSXAdminPassword = "VMware1!VMware1!"
$NSXAuditPassword = "VMware1!VMware1!"

# General Deployment Configuration for Nested ESXi & Cloud Builder VM
$VMDatacenter = "Datacenter"
$VMCluster = "Cluster"
$VMNetwork = "Trunk-Nobinding"
$VMDatastore = "vsanDatastore"
$VMNetmask = "255.255.254.0"
$VMGateway = "10.0.0.1"
$VMDNS = "10.0.0.200"
$VMNTP = "10.0.1.254"
$VMPassword = "VMware1!PSO"
$VMDomain = "home.lab"
$VMSyslog = "10.0.0.123"
$VMFolder = "VCF"

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vcf-lab-deployment.log"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$VAppName = "Nested-VCF-Lab-$random_string"
$SeparateNSXSwitch = $false

$preCheck = 1
$confirmDeployment = 1
$deployNestedESXiVMs = 1
$deployCloudBuilder = 1
$moveVMsIntovApp = 1
$generateJson = 1

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

if($preCheck -eq 1) {
    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`n"
        exit
    }

    if(!(Test-Path $CloudBuilderOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $CloudBuilderOVA ...`n"
        exit
    }

    if($PSVersionTable.PSEdition -ne "Core") {
        Write-Host -ForegroundColor Red "`tPowerShell Core was not detected, please install that before continuing ... `n"
        exit
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- VCF Automated Lab Deployment Configuration ---- "
    Write-Host -NoNewline -ForegroundColor Green "Nested ESXi Image Path: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "Cloud Builder Image Path: "
    Write-Host -ForegroundColor White $CloudBuilderOVA

    Write-Host -ForegroundColor Yellow "`n---- vCenter Server Deployment Target Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "vCenter Server Address: "
    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork

    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore
    Write-Host -NoNewline -ForegroundColor Green "VM Cluster: "
    Write-Host -ForegroundColor White $VMCluster
    Write-Host -NoNewline -ForegroundColor Green "VM vApp: "
    Write-Host -ForegroundColor White $VAppName

    Write-Host -ForegroundColor Yellow "`n---- Cloud Builder Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $CloudbuilderHostname
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $CloudbuilderIP

    Write-Host -ForegroundColor Yellow "`n---- vESXi Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "# of Nested ESXi VMs: "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.count
    Write-Host -NoNewline -ForegroundColor Green "vCPU: "
    Write-Host -ForegroundColor White $NestedESXivCPU
    Write-Host -NoNewline -ForegroundColor Green "vMEM: "
    Write-Host -ForegroundColor White "$NestedESXivMEM GB"
    Write-Host -NoNewline -ForegroundColor Green "Caching VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCachingvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "Capacity VMDK: "
    Write-Host -ForegroundColor White "$NestedESXiCapacityvDisk GB"
    Write-Host -NoNewline -ForegroundColor Green "IP Address(s): "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.Values
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    Write-Host -NoNewline -ForegroundColor Green "DNS: "
    Write-Host -ForegroundColor White $VMDNS
    Write-Host -NoNewline -ForegroundColor Green "NTP: "
    Write-Host -ForegroundColor White $VMNTP
    Write-Host -NoNewline -ForegroundColor Green "Syslog: "
    Write-Host -ForegroundColor White $VMSyslog

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
    Clear-Host
}

if($deployNestedESXiVMs -eq 1 -or $deployCloudBuilder -eq 1) {
    My-Logger "Connecting to Management vCenter Server $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select -First 1
    $cluster = Get-Cluster -Server $viConnection -Name $VMCluster
    $datacenter = $cluster | Get-Datacenter
    $vmhost = $cluster | Get-VMHost | Select -First 1
}

if($deployNestedESXiVMs -eq 1) {
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $networkMapLabel = ($ovfconfig.ToHashTable().keys | where {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
        $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork
        $ovfconfig.common.guestinfo.hostname.value = "${VMName}.${VMDomain}"
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        $ovfconfig.common.guestinfo.ssh.value = $true

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

        My-Logger "Adding vmnic2/vmnic3 for `"$VMNetwork`" and `"$VMNetwork`" to passthrough to Nested ESXi VMs ..."
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet2.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet2.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        $vm | New-AdvancedSetting -name "ethernet3.filter4.name" -value "dvfilter-maclearn" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile
        $vm | New-AdvancedSetting -Name "ethernet3.filter4.onFailure" -value "failOpen" -confirm:$false -ErrorAction SilentlyContinue | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vSAN Cache VMDK size to $NestedESXiCachingvDisk GB & Capacity VMDK size to $NestedESXiCapacityvDisk GB ..."
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiCachingvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Powering On $vmname ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

if($deployCloudBuilder -eq 1) {
    $ovfconfig = Get-OvfConfiguration $CloudBuilderOVA

    $networkMapLabel = ($ovfconfig.ToHashTable().keys | where {$_ -Match "NetworkMapping"}).replace("NetworkMapping.","").replace("-","_").replace(" ","_")
    $ovfconfig.NetworkMapping.$networkMapLabel.value = $VMNetwork
    $ovfconfig.common.guestinfo.hostname.value = $CloudbuilderHostname
    $ovfconfig.common.guestinfo.ip0.value = $CloudbuilderIP
    $ovfconfig.common.guestinfo.netmask0.value = $VMNetmask
    $ovfconfig.common.guestinfo.gateway.value = $VMGateway
    $ovfconfig.common.guestinfo.DNS.value = $VMDNS
    $ovfconfig.common.guestinfo.domain.value = $VMDomain
    $ovfconfig.common.guestinfo.searchpath.value = $VMDomain
    $ovfconfig.common.guestinfo.ntp.value = $VMNTP
    $ovfconfig.common.guestinfo.ADMIN_USERNAME.value = $CloudbuilderAdminUsername
    $ovfconfig.common.guestinfo.ADMIN_PASSWORD.value = $CloudbuilderAdminPassword
    $ovfconfig.common.guestinfo.ROOT_PASSWORD.value = $CloudbuilderRootPassword

    My-Logger "Deploying Cloud Builder VM $CloudbuilderVMName ..."
    $vm = Import-VApp -Source $CloudBuilderOVA -OvfConfiguration $ovfconfig -Name $CloudbuilderVMName -Location $VMCluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

    My-Logger "Powering On $CloudbuilderVMName ..."
    $vm | Start-Vm -RunAsync | Out-Null
}

if($moveVMsIntovApp -eq 1) {
    My-Logger "Creating vApp $VAppName ..."
    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $cluster

    if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
        My-Logger "Creating VM Folder $VMFolder ..."
        $folder = New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm)
    }

    if($deployNestedESXiVMs -eq 1) {
        My-Logger "Moving Nested ESXi VMs into $VAppName vApp ..."
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $vm = Get-VM -Name $_.Key -Server $viConnection
            Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployCloudBuilder -eq 1) {
        $cloudBuilderVM = Get-VM -Name $CloudbuilderVMName -Server $viConnection
        My-Logger "Moving $CloudbuilderVMName into $VAppName vApp ..."
        Move-VM -VM $cloudBuilderVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    My-Logger "Moving $VAppName to VM Folder $VMFolder ..."
    Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile
}

if($deployNestedESXiVMs -eq 1 -or $deployCloudBuilder -eq 1) {
    My-Logger "Disconnecting from $VIServer ..."
    Disconnect-VIServer -Server $viConnection -Confirm:$false
}

if($generateJson -eq 1) {
    if($SeparateNSXSwitch) { $useNSX = "false" } else { $useNSX = "true" }

    $vcfStartConfig1 = @"
{
    "skipEsxThumbprintValidation": true,
    "managementPoolName": "vcf-m01-rp01",
    "sddcManagerSpec": {
        "secondUserCredentials": {
        "username": "vcf",
        "password": "$SddcManagerVcfPassword"
        },
        "ipAddress": "$SddcManagerIP",
        "netmask": "$VMNetmask",
        "hostname": "$SddcManagerName",
        "rootUserCredentials": {
        "username": "root",
        "password": "$SddcManagerRootPassword"
        },
        "restApiCredentials": {
        "username": "admin",
        "password": "$SddcManagerRestPassword"
        },
        "localUserPassword": "$SddcManagerLocalPassword",
        "vcenterId": "vcenter-1"
    },
    "sddcId": "vcf-m01",
    "esxLicense": "$ESXILicense",
    "taskName": "workflowconfig/workflowspec-ems.json",
    "ceipEnabled": true,
    "ntpServers": ["$VMNTP"],
    "dnsSpec": {
        "subdomain": "$VMDomain",
        "domain": "$VMDomain",
        "nameserver": "$VMDNS"
    },
    "networkSpecs": [
        {
        "networkType": "MANAGEMENT",
        "subnet": "$NestedESXiManagementNetworkCidr",
        "gateway": "$VMGateway",
        "vlanId": "0",
        "mtu": "1500",
        "portGroupKey": "vcf-m01-cl01-vds01-pg-mgmt",
        "standbyUplinks":[],
        "activeUplinks":[
            "uplink1",
            "uplink2"
        ]
        },
        {
        "networkType": "VMOTION",
        "subnet": "10.0.3.0/24",
        "gateway": "10.0.3.1",
        "vlanId": "0",
        "mtu": "9000",
        "portGroupKey": "vcf-m01-cl01-vds01-pg-vmotion",
        "association": "vcf-m01-dc01",
        "includeIpAddressRanges": [{"endIpAddress": "10.0.3.8","startIpAddress": "10.0.3.5"}],
        "standbyUplinks":[],
        "activeUplinks":[
            "uplink1",
            "uplink2"
        ]
        },
        {
        "networkType": "VSAN",
        "subnet": "10.0.4.0/24",
        "gateway": "10.0.4.1",
        "vlanId": "0",
        "mtu": "9000",
        "portGroupKey": "vcf-m01-cl01-vds01-pg-vsan",
        "includeIpAddressRanges": [{"endIpAddress": "10.0.4.8", "startIpAddress": "10.0.4.5"}],
        "standbyUplinks":[],
        "activeUplinks":[
            "uplink1",
            "uplink2"
        ]
        }
    ],
    "nsxtSpec":
    {
        "nsxtManagerSize": "small",
        "nsxtManagers": [
        {
            "hostname": "$NSXManagerNode1Name",
            "ip": "$NSXManagerNode1IP"
        }
        ],
        "rootNsxtManagerPassword": "$NSXRootPassword",
        "nsxtAdminPassword": "$NSXAdminPassword",
        "nsxtAuditPassword": "$NSXAuditPassword",
        "rootLoginEnabledForNsxtManager": "true",
        "sshEnabledForNsxtManager": "true",
        "overLayTransportZone": {
            "zoneName": "vcf-m01-tz-overlay01",
            "networkName": "netName-overlay"
        },
        "vlanTransportZone": {
            "zoneName": "vcf-m01-tz-vlan01",
            "networkName": "netName-vlan"
        },
        "vip": "$NSXManagerVIPIP",
        "vipFqdn": "$NSXManagerVIPName",
        "nsxtLicense": "$NSXLicense",
        "transportVlanId": 2005
    },
    "vsanSpec": {
        "vsanName": "vsan-1",
        "vsanDedup": "false",
        "licenseFile": "$VSANLicense",
        "datastoreName": "vcf-m01-cl01-ds-vsan01"
    },
    "dvSwitchVersion": "7.0.0",
    "dvsSpecs": [
        {
        "dvsName": "vcf-m01-cl01-vds01",
        "vcenterId":"vcenter-1",
        "vmnics": [
            "vmnic0",
            "vmnic1"
        ],
        "mtu": 9000,
        "networks":[
            "MANAGEMENT",
            "VMOTION",
            "VSAN"
        ],
        "niocSpecs":[
            {
            "trafficType":"VSAN",
            "value":"HIGH"
            },
            {
            "trafficType":"VMOTION",
            "value":"LOW"
            },
            {
            "trafficType":"VDP",
            "value":"LOW"
            },
            {
            "trafficType":"VIRTUALMACHINE",
            "value":"HIGH"
            },
            {
            "trafficType":"MANAGEMENT",
            "value":"NORMAL"
            },
            {
            "trafficType":"NFS",
            "value":"LOW"
            },
            {
            "trafficType":"HBR",
            "value":"LOW"
            },
            {
            "trafficType":"FAULTTOLERANCE",
            "value":"LOW"
            },
            {
            "trafficType":"ISCSI",
            "value":"LOW"
            }
        ],
        "isUsedByNsxt": $useNSX
        }
"@

    $vcfNetworkConfig = @"
        ,{
            "dvsName": "vcf-m01-nsx-vds01",
            "vcenterId":"vcenter-1",
            "vmnics": [
                "vmnic2",
                "vmnic3"
            ],
            "mtu": 9000,
            "networks":[
            ],
            "isUsedByNsxt": true
        }
"@

    if($SeparateNSXSwitch) {
        $vcfStartConfig1 = $vcfStartConfig1 + $vcfNetworkConfig
    }

    $vcfStartConfig2 =
@"
    ],
    "clusterSpec":
    {
        "clusterName": "vcf-m01-cl01",
        "vcenterName": "vcenter-1",
        "clusterEvcMode": "",
        "vmFolders": {
        "MANAGEMENT": "vcf-m01-fd-mgmt",
        "NETWORKING": "vcf-m01-fd-nsx",
        "EDGENODES": "vcf-m01-fd-edge"
        }
    },
    "resourcePoolSpecs": [{
        "name": "vcf-m01-cl01-rp-sddc-mgmt",
        "type": "management",
        "cpuReservationPercentage": 0,
        "cpuLimit": -1,
        "cpuReservationExpandable": true,
        "cpuSharesLevel": "normal",
        "cpuSharesValue": 0,
        "memoryReservationMb": 0,
        "memoryLimit": -1,
        "memoryReservationExpandable": true,
        "memorySharesLevel": "normal",
        "memorySharesValue": 0
    }, {
        "name": "vcf-m01-cl01-rp-sddc-edge",
        "type": "network",
        "cpuReservationPercentage": 0,
        "cpuLimit": -1,
        "cpuReservationExpandable": true,
        "cpuSharesLevel": "normal",
        "cpuSharesValue": 0,
        "memoryReservationPercentage": 0,
        "memoryLimit": -1,
        "memoryReservationExpandable": true,
        "memorySharesLevel": "normal",
        "memorySharesValue": 0
    }, {
        "name": "vcf-m01-cl01-rp-user-edge",
        "type": "compute",
        "cpuReservationPercentage": 0,
        "cpuLimit": -1,
        "cpuReservationExpandable": true,
        "cpuSharesLevel": "normal",
        "cpuSharesValue": 0,
        "memoryReservationPercentage": 0,
        "memoryLimit": -1,
        "memoryReservationExpandable": true,
        "memorySharesLevel": "normal",
        "memorySharesValue": 0
    }, {
        "name": "vcf-m01-cl01-rp-user-vm",
        "type": "compute",
        "cpuReservationPercentage": 0,
        "cpuLimit": -1,
        "cpuReservationExpandable": true,
        "cpuSharesLevel": "normal",
        "cpuSharesValue": 0,
        "memoryReservationPercentage": 0,
        "memoryLimit": -1,
        "memoryReservationExpandable": true,
        "memorySharesLevel": "normal",
        "memorySharesValue": 0
        }]
    ,
    "pscSpecs": [
        {
        "pscId": "psc-1",
        "vcenterId": "vcenter-1",
        "adminUserSsoPassword": "$VCSASSOPassword",
        "pscSsoSpec": {
            "ssoDomain": "vsphere.local"
        }
        }
    ],
    "vcenterSpec": {
        "vcenterIp": "$VCSAIP",
        "vcenterHostname": "$VCSAName",
        "vcenterId": "vcenter-1",
        "licenseFile": "$VCSALicense",
        "vmSize": "tiny",
        "storageSize": "",
        "rootVcenterPassword": "$VCSARootPassword"
    },
    "hostSpecs": [
"@

        $vcfMiddleConfig = ""

        $count = 1
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $VMName = $_.Key
            $VMIPAddress = $_.Value

            $vcfMiddleConfig += @"
    {
        "association": "vcf-m01-dc01",
        "ipAddressPrivate": {
            "ipAddress": "$VMIPAddress",
            "cidr": "$NestedESXiManagementNetworkCidr",
            "gateway": "$VMGateway"
        },
        "hostname": "$VMName",
        "credentials": {
            "username": "root",
            "password": "$VMPassword"
        },
        "sshThumbprint": "SHA256:DUMMY_VALUE",
        "sslThumbprint": "SHA25_DUMMY_VALUE",
        "vSwitch": "vSwitch0",
        "serverId": "host-$count"
    },
"@
    $count++
    }
    $vcfMiddleConfig = $vcfMiddleConfig.Substring(0,$vcfMiddleConfig.Length-1)

    $vcfEndConfig = @"
    ],
    "excludedComponents": ["NSX-V", "AVN", "EBGP"]
}
"@

    $vcfConfig = $vcfStartConfig1 + $vcfStartConfig2 + $vcfMiddleConfig + $vcfEndConfig

    My-Logger "Generating Cloud Builder VCF configuration deployment file vcf-config.json"
    $vcfConfig  | Out-File -LiteralPath vcf-config.json
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "VCF Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"