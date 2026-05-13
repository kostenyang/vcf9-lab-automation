#!/bin/bash
###############################################################################
# VCF 9.1 - VCF Installer / SDDC Manager Lab Workarounds
# Source:
#   https://williamlam.com/2026/05/vcf-9-1-comprehensive-vcf-installer-sddc-manager-configuration-workarounds-for-lab-deployments.html
#
# Usage:
#   1) Edit the variables in the "USER EDITABLE VARIABLES" section below.
#   2) Run from a Linux/macOS host that can SSH to the VCF Installer:
#         chmod +x vcf91-lab-workarounds.sh
#         ./vcf91-lab-workarounds.sh
#      Or copy the script onto the VCF Installer and run locally with:
#         RUN_MODE=local ./vcf91-lab-workarounds.sh
#
#   The script is idempotent: each key=value line is replaced if it already
#   exists, or appended if it is missing.
###############################################################################

set -euo pipefail

############################  USER EDITABLE VARIABLES  ########################

# --- Connection -------------------------------------------------------------
VCF_INSTALLER_IP="10.0.1.4"
SSH_USER="root"                 # account to SSH/sudo with
SSH_PORT="22"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
RUN_MODE="ssh"                  # "ssh" (default) or "local" if running on the installer itself

# --- Config file paths (rarely need to change) ------------------------------
FEATURE_PROPS="/home/vcf/feature.properties"
APP_PROPS="/etc/vmware/vcf/domainmanager/application.properties"

# --- Restart commands -------------------------------------------------------
RESTART_SDDC_SERVICES="echo 'y' | /opt/vmware/vcf/operationsmanager/scripts/cli/sddcmanager_restart_services.sh"
RESTART_DOMAINMANAGER="systemctl restart domainmanager"

# --- Workaround toggles (true = apply, false = skip) ------------------------
ENABLE_SINGLE_HOST_DOMAIN="true"        # 1/2/3-host (non-nested) VCF fleet
DISABLE_10GBE_PNIC_CHECK="true"         # Allow <10GbE pNICs
DISABLE_VSAN_ESA_HCL_CHECK="true"       # Bypass vSAN ESA HCL
DISABLE_VMOTION_CONNECTIVITY_CHECK="true"   # vMotion connectivity + L3 gw
DISABLE_VSAN_CONNECTIVITY_CHECK="true"  # vSAN connectivity
DISABLE_TEP_MTU_CHECK="true"            # ESX TEP MTU / network connectivity
ENABLE_NFS_PRINCIPAL_STORAGE="false"    # Single ESX host w/ NFS principal storage
INCREASE_RETRY_MAX="true"               # orchestrator.task.retry.max
INCREASE_NSXM_TIMEOUT="true"            # NSX Manager deployment timeout
INCREASE_NSX_EDGE_TIMEOUT="true"        # NSX Edge deployment timeout
INCREASE_VCF_MGMT_TIMEOUT="true"        # VCF Management services bootstrap
INCREASE_ALB_TIMEOUT="true"             # VMware Avi LB image upload retry

# --- Tunable values ---------------------------------------------------------
RETRY_MAX="5"                                  # orchestrator.task.retry.max
NSXT_MANAGER_WAIT_MINUTES="180"                # nsxt.manager.wait.minutes
EDGE_NODE_VM_CREATION_MAX_WAIT_MINUTES="90"    # edge.node.vm.creation.max.wait.minutes
VSP_BOOTSTRAP_TASK_TIMEOUT_MINUTES="240"       # vsp.bootstrap.task.timeout.minutes
VSP_BOOTSTRAP_COMMAND_TIMEOUT_MINUTES="200"    # vsp.bootstrap.command.timeout.minutes
ALB_IMAGE_UPLOAD_RETRY_INTERVAL_SECONDS="90"   # nsxt.alb.image.upload.retry.check.interval.seconds

# Restart services automatically at the end?
DO_RESTART="true"

###############################  END OF VARIABLES  ############################


# --- Helpers ----------------------------------------------------------------
run_remote() {
    # Run a command either locally or over SSH depending on RUN_MODE
    local cmd="$1"
    if [[ "${RUN_MODE}" == "local" ]]; then
        bash -c "${cmd}"
    else
        # shellcheck disable=SC2029
        ssh ${SSH_OPTS} -p "${SSH_PORT}" "${SSH_USER}@${VCF_INSTALLER_IP}" "${cmd}"
    fi
}

# Replace-or-append a key=value pair inside a remote file.
# Matches the key with optional surrounding whitespace and '=' separator.
upsert_kv() {
    local file="$1"
    local key="$2"
    local value="$3"

    # Escape characters that have meaning in sed regex/replacement
    local key_re
    key_re=$(printf '%s' "$key" | sed 's/[][\/.^$*]/\\&/g')
    local val_esc
    val_esc=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')

    local cmd="if [ ! -f '${file}' ]; then mkdir -p \$(dirname '${file}'); touch '${file}'; fi; "
    cmd+="if grep -Eq '^[[:space:]]*${key_re}[[:space:]]*=' '${file}'; then "
    cmd+="  sed -i 's|^[[:space:]]*${key_re}[[:space:]]*=.*|${key}=${val_esc}|' '${file}'; "
    cmd+="else "
    cmd+="  printf '\\n%s=%s\\n' '${key}' '${value}' >> '${file}'; "
    cmd+="fi"

    echo "  -> ${file} :: ${key}=${value}"
    run_remote "${cmd}"
}

apply_feature_prop() {
    upsert_kv "${FEATURE_PROPS}" "$1" "$2"
    FEATURE_TOUCHED="true"
}

apply_app_prop() {
    upsert_kv "${APP_PROPS}" "$1" "$2"
    APP_TOUCHED="true"
}

FEATURE_TOUCHED="false"
APP_TOUCHED="false"

echo "================================================================="
echo "VCF 9.1 Lab Workarounds  ->  ${VCF_INSTALLER_IP}   mode=${RUN_MODE}"
echo "================================================================="

# --- Apply workarounds ------------------------------------------------------

if [[ "${ENABLE_SINGLE_HOST_DOMAIN}" == "true" ]]; then
    echo "[*] Enable Single/Dual ESX host deployment"
    apply_feature_prop "feature.vcf.vgl-29121.single.host.domain" "true"
fi

if [[ "${DISABLE_10GBE_PNIC_CHECK}" == "true" ]]; then
    echo "[*] Disable 10GbE pNIC check"
    apply_app_prop "enable.speed.of.physical.nics.validation" "false"
fi

if [[ "${DISABLE_VSAN_ESA_HCL_CHECK}" == "true" ]]; then
    echo "[*] Disable vSAN ESA HCL check"
    apply_feature_prop "feature.vcf.vgl-43370.vsan.esa.sddc.managed.disk.claim" "true"
    apply_app_prop     "vsan.esa.sddc.managed.disk.claim" "true"
fi

if [[ "${DISABLE_VMOTION_CONNECTIVITY_CHECK}" == "true" ]]; then
    echo "[*] Disable vMotion connectivity check"
    apply_app_prop "validation.disable.vmotion.connectivity.check" "true"
    apply_app_prop "validation.disable.vmotion.l3.gateway.connectivity.check" "true"
fi

if [[ "${DISABLE_VSAN_CONNECTIVITY_CHECK}" == "true" ]]; then
    echo "[*] Disable vSAN connectivity check"
    apply_app_prop "validation.disable.vsan.connectivity.check" "true"
fi

if [[ "${DISABLE_TEP_MTU_CHECK}" == "true" ]]; then
    echo "[*] Disable ESX TEP MTU check"
    apply_app_prop "validation.disable.network.connectivity.check" "true"
    apply_app_prop "nsxt.mtu.validation.skip" "true"
fi

if [[ "${ENABLE_NFS_PRINCIPAL_STORAGE}" == "true" ]]; then
    echo "[*] Single ESX host w/ NFS principal storage"
    apply_app_prop "validation.disable.nfs.configuration.connectivity.check" "true"
fi

if [[ "${INCREASE_RETRY_MAX}" == "true" ]]; then
    echo "[*] Increase VCF general deployment retry"
    apply_app_prop "orchestrator.task.retry.max" "${RETRY_MAX}"
fi

if [[ "${INCREASE_NSXM_TIMEOUT}" == "true" ]]; then
    echo "[*] Increase NSX Manager deployment timeout"
    apply_app_prop "nsxt.manager.wait.minutes" "${NSXT_MANAGER_WAIT_MINUTES}"
fi

if [[ "${INCREASE_NSX_EDGE_TIMEOUT}" == "true" ]]; then
    echo "[*] Increase NSX Edge deployment timeout"
    apply_app_prop "edge.node.vm.creation.max.wait.minutes" "${EDGE_NODE_VM_CREATION_MAX_WAIT_MINUTES}"
fi

if [[ "${INCREASE_VCF_MGMT_TIMEOUT}" == "true" ]]; then
    echo "[*] Increase VCF Management Services deployment timeout"
    apply_app_prop "vsp.bootstrap.task.timeout.minutes"    "${VSP_BOOTSTRAP_TASK_TIMEOUT_MINUTES}"
    apply_app_prop "vsp.bootstrap.command.timeout.minutes" "${VSP_BOOTSTRAP_COMMAND_TIMEOUT_MINUTES}"
fi

if [[ "${INCREASE_ALB_TIMEOUT}" == "true" ]]; then
    echo "[*] Increase VMware Avi Load Balancer deployment timeout"
    apply_app_prop "nsxt.alb.image.upload.retry.check.interval.seconds" "${ALB_IMAGE_UPLOAD_RETRY_INTERVAL_SECONDS}"
fi

# --- Restart services -------------------------------------------------------
if [[ "${DO_RESTART}" == "true" ]]; then
    if [[ "${FEATURE_TOUCHED}" == "true" ]]; then
        echo "[*] Restarting SDDC Manager services (feature.properties was changed)"
        run_remote "${RESTART_SDDC_SERVICES}"
    fi
    if [[ "${APP_TOUCHED}" == "true" ]]; then
        echo "[*] Restarting domainmanager (application.properties was changed)"
        run_remote "${RESTART_DOMAINMANAGER}"
    fi
else
    echo "[!] DO_RESTART=false  -> remember to restart services manually:"
    [[ "${FEATURE_TOUCHED}" == "true" ]] && echo "    ${RESTART_SDDC_SERVICES}"
    [[ "${APP_TOUCHED}" == "true" ]]     && echo "    ${RESTART_DOMAINMANAGER}"
fi

echo "================================================================="
echo "Done."
echo "================================================================="
