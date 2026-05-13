#!/usr/bin/env python3
"""
VCF Lab MCP Server
Runs on Ubuntu 10.0.0.65, exposes tools for Claude to interact with the VCF9 lab.

Tools:
  ssh_exec              - SSH into any lab machine and run a command
  get_ssl_thumbprint    - Get SHA-256 SSL cert thumbprint from ESXi / vCenter
  vcenter_api           - vCenter REST API calls
  vcf_installer_api     - VCF Installer REST API calls (bringup, status, bundles)
  sddc_manager_api      - SDDC Manager REST API calls
  check_dns             - Resolve FQDN via lab DNS server
  ping_host             - Ping a host

Start:  python3 vcf-lab-mcp-server.py
Port:   http://0.0.0.0:7000/sse
"""

import hashlib
import json
import pathlib
import socket
import ssl
import subprocess

import paramiko
import requests
import urllib3
import uvicorn
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Lab defaults (override via tool arguments if needed) ─────────────────────
VCENTER_IP   = "10.0.0.101"
VCENTER_USER = "administrator@vsphere.local"
VCENTER_PASS = "VMware1!"

VCF_INSTALLER_IP   = "10.0.1.4"
VCF_INSTALLER_USER = "admin@local"
VCF_INSTALLER_PASS = "VMw@re123!PSO777"

SDDC_MANAGER_IP   = "10.0.1.5"
SDDC_MANAGER_USER = "administrator@vsphere.local"
SDDC_MANAGER_PASS = "VMware1!VMware1!"

DNS_SERVER = "10.0.0.200"

SSL_CERTFILE = "/opt/vcf-mcp/cert.pem"
SSL_KEYFILE  = "/opt/vcf-mcp/key.pem"

# ── API Keys — 從 /opt/vcf-mcp/keys.json 載入（不寫死在 source 裡）─────────────
# 格式: {"使用者名稱": "Bearer token", ...}
# 產生新 key: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
API_KEYS_FILE = pathlib.Path("/opt/vcf-mcp/keys.json")


def _load_api_keys() -> dict[str, str]:
    if not API_KEYS_FILE.exists():
        raise RuntimeError(f"API keys file not found: {API_KEYS_FILE}")
    with API_KEYS_FILE.open() as f:
        keys = json.load(f)
    if not isinstance(keys, dict) or not keys:
        raise RuntimeError("Invalid keys file: must be non-empty JSON object")
    return keys


API_KEYS: dict[str, str] = _load_api_keys()

mcp = FastMCP(
    "vcf-lab",
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=False,
    ),
)


# ── API Key Middleware (pure ASGI, SSE-safe) ──────────────────────────────────
class APIKeyMiddleware:
    def __init__(self, app):
        self.app = app
        self._VALID = frozenset(API_KEYS.values())

    def _extract_token(self, scope) -> str:
        # 1. Authorization: Bearer <token> header
        headers = {k.lower(): v for k, v in scope.get("headers", [])}
        auth = headers.get(b"authorization", b"").decode()
        if auth.startswith("Bearer "):
            return auth[7:].strip()
        # 2. ?api_key=<token> query string
        qs = scope.get("query_string", b"").decode()
        for part in qs.split("&"):
            if part.startswith("api_key="):
                return part[8:]
        return ""

    async def __call__(self, scope, receive, send):
        if scope["type"] in ("http", "websocket"):
            if self._extract_token(scope) not in self._VALID:
                await send({
                    "type": "http.response.start",
                    "status": 401,
                    "headers": [
                        [b"content-type", b"application/json"],
                        [b"www-authenticate", b'Bearer realm="vcf-lab"'],
                    ],
                })
                await send({"type": "http.response.body",
                            "body": b'{"error":"Unauthorized"}'})
                return
        await self.app(scope, receive, send)

# ── Helpers ───────────────────────────────────────────────────────────────────

def _vcenter_token(ip=VCENTER_IP, user=VCENTER_USER, pwd=VCENTER_PASS) -> str:
    resp = requests.post(f"https://{ip}/api/session", auth=(user, pwd), verify=False, timeout=10)
    resp.raise_for_status()
    return resp.json()

def _vcf_token(ip=VCF_INSTALLER_IP, user=VCF_INSTALLER_USER, pwd=VCF_INSTALLER_PASS) -> str:
    resp = requests.post(
        f"https://{ip}/v1/tokens",
        json={"username": user, "password": pwd},
        verify=False, timeout=10,
    )
    resp.raise_for_status()
    return resp.json().get("accessToken", "")

def _sddc_token(ip=SDDC_MANAGER_IP, user=SDDC_MANAGER_USER, pwd=SDDC_MANAGER_PASS) -> str:
    resp = requests.post(
        f"https://{ip}/v1/tokens",
        json={"username": user, "password": pwd},
        verify=False, timeout=10,
    )
    resp.raise_for_status()
    return resp.json().get("accessToken", "")

# ── Tools ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def ssh_exec(host: str, command: str, username: str = "root", password: str = "VMware1!VMware1!") -> str:
    """
    Execute a shell command on any lab host via SSH and return stdout+stderr.
    Works for ESXi hosts, SDDC Manager, VCF Installer, etc.
    Example: ssh_exec("10.0.1.10", "esxcli system version get")
    """
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username=username, password=password, timeout=30,
                       look_for_keys=False, allow_agent=False)
        _, stdout, stderr = client.exec_command(command, timeout=60)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        return (out + err).strip() or "(no output)"
    except Exception as exc:
        return f"SSH error connecting to {host}: {exc}"
    finally:
        client.close()


@mcp.tool()
def get_ssl_thumbprint(host: str, port: int = 443) -> str:
    """
    Return the SHA-256 SSL certificate thumbprint (colon-separated) for any host.
    Useful for getting ESXi thumbprints before VCF bringup.
    Example: get_ssl_thumbprint("10.0.1.10")
    """
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with socket.create_connection((host, port), timeout=10) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as tls:
                der = tls.getpeercert(binary_form=True)
                digest = hashlib.sha256(der).hexdigest().upper()
                return ":".join(digest[i:i+2] for i in range(0, len(digest), 2))
    except Exception as exc:
        return f"Error getting thumbprint from {host}:{port}: {exc}"


@mcp.tool()
def vcenter_api(
    method: str,
    path: str,
    body: str = "",
    vcenter_ip: str = VCENTER_IP,
    username: str = VCENTER_USER,
    password: str = VCENTER_PASS,
) -> str:
    """
    Make a vCenter REST API call.
    method : GET | POST | PUT | PATCH | DELETE
    path   : e.g. /api/vcenter/cluster, /api/vcenter/host
    body   : JSON string for POST/PUT/PATCH (leave empty for GET/DELETE)

    Examples:
      vcenter_api("GET", "/api/vcenter/cluster")
      vcenter_api("GET", "/api/vcenter/host")
      vcenter_api("GET", "/api/vcenter/datastore")
    """
    try:
        token = _vcenter_token(vcenter_ip, username, password)
        headers = {"vmware-api-session-id": token, "Content-Type": "application/json"}
        resp = requests.request(
            method.upper(), f"https://{vcenter_ip}{path}",
            headers=headers, data=body or None, verify=False, timeout=30,
        )
        return f"HTTP {resp.status_code}\n{resp.text[:6000]}"
    except Exception as exc:
        return f"vCenter API error: {exc}"


@mcp.tool()
def vcf_installer_api(
    method: str,
    path: str,
    body: str = "",
    installer_ip: str = VCF_INSTALLER_IP,
    username: str = VCF_INSTALLER_USER,
    password: str = VCF_INSTALLER_PASS,
) -> str:
    """
    Make a VCF Installer REST API call.
    method : GET | POST | PUT | PATCH | DELETE
    path   : e.g. /v1/system/appliance-info, /v1/sddcs, /v1/bundles/download-status

    Common use cases:
      vcf_installer_api("GET", "/v1/system/appliance-info")        # check ready
      vcf_installer_api("GET", "/v1/sddcs")                        # deployment status
      vcf_installer_api("POST", "/v1/sddcs", body=<json_string>)   # start bringup
      vcf_installer_api("GET", "/v1/system/settings/depot")        # depot config
    """
    try:
        token = _vcf_token(installer_ip, username, password)
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        resp = requests.request(
            method.upper(), f"https://{installer_ip}{path}",
            headers=headers, data=body or None, verify=False, timeout=30,
        )
        return f"HTTP {resp.status_code}\n{resp.text[:6000]}"
    except Exception as exc:
        return f"VCF Installer API error: {exc}"


@mcp.tool()
def sddc_manager_api(
    method: str,
    path: str,
    body: str = "",
    sddc_ip: str = SDDC_MANAGER_IP,
    username: str = SDDC_MANAGER_USER,
    password: str = SDDC_MANAGER_PASS,
) -> str:
    """
    Make an SDDC Manager REST API call.
    method : GET | POST | PUT | PATCH | DELETE
    path   : e.g. /v1/domains, /v1/hosts, /v1/clusters, /v1/tasks

    Examples:
      sddc_manager_api("GET", "/v1/domains")
      sddc_manager_api("GET", "/v1/hosts?status=UNASSIGNED_USEABLE")
      sddc_manager_api("GET", "/v1/tasks?status=Failed")
    """
    try:
        token = _sddc_token(sddc_ip, username, password)
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        resp = requests.request(
            method.upper(), f"https://{sddc_ip}{path}",
            headers=headers, data=body or None, verify=False, timeout=30,
        )
        return f"HTTP {resp.status_code}\n{resp.text[:6000]}"
    except Exception as exc:
        return f"SDDC Manager API error: {exc}"


@mcp.tool()
def check_dns(fqdn: str, dns_server: str = DNS_SERVER) -> str:
    """
    Resolve an FQDN using the lab DNS server (10.0.0.200).
    Useful for verifying DNS records before VCF bringup.
    Example: check_dns("vcf-m01-vc01.home.lab")
    """
    try:
        result = subprocess.run(
            ["nslookup", fqdn, dns_server],
            capture_output=True, text=True, timeout=10,
        )
        return (result.stdout + result.stderr).strip()
    except Exception as exc:
        return f"DNS check error: {exc}"


@mcp.tool()
def ping_host(host: str, count: int = 3) -> str:
    """
    Ping a lab host to check network reachability.
    Example: ping_host("10.0.1.10")
    """
    try:
        result = subprocess.run(
            ["ping", "-c", str(count), host],
            capture_output=True, text=True, timeout=20,
        )
        return (result.stdout + result.stderr).strip()
    except Exception as exc:
        return f"Ping error: {exc}"


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Starting VCF Lab MCP Server on https://0.0.0.0:7000/sse")
    print(f"API keys loaded: {list(API_KEYS.keys())}")
    uvicorn.run(
        APIKeyMiddleware(mcp.sse_app()),
        host="0.0.0.0",
        port=7000,
        ssl_keyfile=SSL_KEYFILE,
        ssl_certfile=SSL_CERTFILE,
    )
