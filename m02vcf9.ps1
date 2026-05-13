# Physical vCenter Server environment
$VIServer = "labvc.lab.com"
$VIUsername = "administrator@vsphere.local"
$VIPassword = "VMware1!"

# General Deployment Configuration
$VAppLabel = "Kosten-VCF9"
$VMDatacenter = "Datacenter"
$VMCluster = "Cluster"
$VMNetwork = "Trunk-Nobinding"
$VMDatastore = "vsanDatastore"
$VMNetmask = "255.255.254.0"
$VMGateway = "10.0.0.1"
$VMDNS = "10.0.0.200"
$VMNTP = "10.0.1.254"
$VMPassword = "VMware1!VMware1!"
$VMDomain = "home.lab"
$VMSyslog = "10.0.0.123"
$VMFolder = "VCF"

# Enable Debugging
$Debug = $false

# Full Path to both the Nested ESXi & VCF Installer OVA
$NestedESXiApplianceOVA = "E:\Nested_ESXi9.0.1_Appliance_Template_v1.0.ova"
$VCFInstallerOVA = "E:\VCF-SDDC-Manager-Appliance-9.0.0.0.24703748.ova"

# VCF Version
$VCFInstallerProductVersion = "9.0.1.0"
$VCFInstallerProductSKU = "VCF"

# VCF Software Depot Configuration
$VCFInstallerSoftwareDepot = "online" #online or offline
$VCFInstallerDepotToken = "Pqi6C1e6o1tWi2oV5dgMNPy4niq20TZ2"

# Offline Depot Configurations (optional)
$VCFInstallerDepotUsername = "vcf"
$VCFInstallerDepotPassword = "VMware1!VMware1!"
$VCFInstallerDepotHost = "172.16.1.54"
$VCFInstallerDepotPort = 8888
$VCFInstallerDepotHttps = $false

# VCF Fleet Deployment Configuration
$DeploymentInstanceName = "vcf"
$DeploymentId = "vcf-m01"
$CEIPEnabled = $true
$FIPSEnabled = $true

# VCF Installer Configurations
$VCFInstallerVMName = "vcf-m02-sddcm01.home.lab-new"
$VCFInstallerFQDN = "vcf-m02-sddcm01.home.lab"
$VCFInstallerIP = "10.0.1.18"
$VCFInstallerAdminUsername = "admin@local"
$VCFInstallerAdminPassword = "VMware1!VMware1!"
$VCFInstallerRootPassword = "VMware1!VMware1!"

# SDDC Manager Configuration
$SddcManagerHostname = "vcfsddc-9.home.lab"
$SddcManagerIP = "10.0.0.164"
$SddcManagerRootPassword = "VMware1!VMware1!"
$SddcManagerVcfPassword = "VMware1!VMware1!"
$SddcManagerSSHPassword = "VMware1!VMware1!"
$SddcManagerLocalPassword = "VMware1!VMware1!"

# Nested ESXi VMs for Management Domain
$NestedESXiHostnameToIPsForManagementDomain = @{
    "vcf-m02-esx01"   = "10.0.1.14"
    "vcf-m02-esx02"   = "10.0.1.15"
    "vcf-m02-esx03"   = "10.0.1.16"
    "vcf-m02-esx04"   = "10.0.1.17"
}

# Nested ESXi VMs for Workload Domain
$NestedESXiHostnameToIPsForWorkloadDomain = @{
    "esx04"   = "172.16.30.4"
    "esx05"   = "172.16.30.5"
    "esx06"   = "172.16.30.6"
}

# Nested ESXi VM Resources for Management Domain
$NestedESXiMGMTvCPU = "24"
$NestedESXiMGMTvMEM = "112" #GB
$NestedESXiMGMTCachingvDisk = "32" #GB
$NestedESXiMGMTCapacityvDisk = "700" #GB
$NestedESXiMGMTBootDisk = "64" #GB

# Nested ESXi VM Resources for Workload Domain
$NestedESXiWLDvCPU = "16"
$NestedESXiWLDvMEM = "32" #GB
$NestedESXiWLDCachingvDisk = "32" #GB
$NestedESXiWLDCapacityvDisk = "250" #GB
$NestedESXiWLDBootDisk = "64" #GB

# ESXi Network Configuration
$NestedESXiManagementNetworkCidr = "10.0.0./16" # should match $VMNetwork configuration
$NestedESXivMotionNetworkCidr = "10.1.32.0/24"
$NestedESXivSANNetworkCidr = "10.1.33.0/24"
$NestedESXiNSXTepNetworkCidr = "10.1.34.0/24"

# vCenter Configuration
$VCSAName = "vcf-m02-vc01"
$VCSAIP = "10.0.1.19"
$VCSARootPassword = "VMware1!VMware1!"
$VCSASSOPassword = "VMware1!VMware1!"
$VCSASize = "small"
$VCSAEnableVCLM = $true
$VCSADatacenterName = "vcf-m02-dc"
$VCSAClusterName = "vcf-m02-cl01"

#vSAN Configuration
$VSANFTT = 0
$VSANDedupe = $false
$VSANESAEnabled = $false
$VSANDatastoreName = "vsanDatastore"

# VCF Operations Configuration
$VCFOperationsSize = "small"
$VCFOperationsHostname = "vcf9ops.home.lab"
$VCFOperationsIP = "10.0.0.160"
$VCFOperationsRootPassword = "VMware1!VMware1!"
$VCFOperationsAdminPassword = "VMware1!VMware1!"

# NSX Configuration
$NSXManagerSize = "medium"
$NSXManagerVIPHostname = "vcf-m02-nsx01.home.lab"
$NSXManagerVIPIP = "10.0.1.21"
$NSXManagerNodeHostname = "vcf-m02-nsx01a.home.lab"
$NSXManagerNodeIP = "10.0.1.20"
$NSXRootPassword = "VMware1!VMware1!"
$NSXAdminPassword = "VMware1!VMware1!"
$NSXAuditPassword = "VMware1!VMware1!"

# VCF Operations Collector
$VCFOperationsCollectorSize = "small"
$VCFOperationsCollectorHostname = "vcf9opsc.home.lab"
$VCFOperationsCollectorRootPassword = "VMware1!VMware1!"

# VCF Operations Fleet Manager
$VCFOperationsFleetManagerHostname = "vcf9fleet.home.lab"
$VCFOperationsFleetManagerAdminPassword = "VMware1!VMware1!"
$VCFOperationsFleetManagerRootPassword = "VMware1!VMware1!"

# VCF Automation
$VCFAutomationHostname = "auto01"
$VCFAutomationAdminPassword = "VMware1!VMware1!"
$VCFAutomationIPPool = @("172.16.30.23","172.16.30.24")
$VCFAutomationNodePrefix = "vcf-lamw-auto"
$VCFAutomationClusterCIDR = "198.18.0.0/15"

# VCF Workload Domain Configurations
$VCFWorkloadDomainName = "vcf-w01"
$VCFWorkloadDomainOrgName = "vcf-w01"
$VCFWorkloadDomainEnableVCLM = $true
$VCFWorkloadDomainEnableVSANESA = $false

# WLD vCenter Configuration
$VCFWorkloadDomainVCSAHostname = "vc02"
$VCFWorkloadDomainVCSAIP = "172.16.30.40"
$VCFWorkloadDomainVCSARootPassword = "VMware1!VMware1!"
$VCFWorkloadDomainVCSASSOPassword = "VMware1!VMware1!"
$VCFWorkloadDomainVCSADatacenterName = "vcf-wld-dc"
$VCFWorkloadDomainVCSAClusterName = "vcf-wld-cl01"

# WLD NSX Configuration
$VCFWorkloadDomainNSXManagerVIPHostname = "nsx02"
$VCFWorkloadDomainNSXManagerNode1Hostname = "nsx02a"
$VCFWorkloadDomainNSXManagerNode1IP = "172.16.30.42"
$VCFWorkloadDomainNSXAdminPassword = "VMware1!VMware1!"
$VCFWorkloadDomainSeparateNSXSwitch = $false
