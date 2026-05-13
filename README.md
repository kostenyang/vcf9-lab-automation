# VCF9 Lab 自動化部署 — 使用手冊

## 環境概覽

| 角色 | IP | 說明 |
|------|----|------|
| 管理 vCenter | 10.0.0.101 (labvc.lab.com) | 部署 Nested VM 的目標 |
| AD / DNS / 跳板機 | 10.0.0.200 | DNS、source 檔案存放 |
| MCP Server (Ubuntu) | 10.0.0.65 | Claude AI lab 操作工具 |
| VCF Installer | 10.0.1.4 | VCF9 bringup 控制台 |
| SDDC Manager (M01) | 10.0.1.5 | VCF9 管理 domain |
| Nested ESXi (M01) | 10.0.1.10–13 | VCF9 Management Domain hosts |
| Nested ESXi (M02) | 10.0.1.14–17 | VCF5.x Workload Domain hosts |

---

## 腳本說明

### 1. `autodeployvcf9m01.ps1` — VCF9 Management Domain VM 部署

**用途**：在 vCenter (10.0.0.101) 上部署 4 台 Nested ESXi + 1 台 VCF Installer OVA，並產生 JSON 設定檔。

**前置條件**

| 項目 | 說明 |
|------|------|
| PowerShell | Core (`pwsh`) 7+ |
| PowerCLI | 需已安裝 (`Install-Module VMware.PowerCLI`) |
| OVA 檔案 | `E:\Nested_ESXi9.0.2_Appliance_Template_v1.0.ova` |
| OVA 檔案 | `E:\VCF-SDDC-Manager-Appliance-9.0.1.0.24962180.ova` |

**執行方式**

```powershell
cd "C:\Users\Administrator\OneDrive\桌面\VCF\VCF9\vcf9autodeploy"
pwsh -File .\autodeployvcf9m01.ps1
```

**執行流程**

```
[preCheck]    → 檢查 OVA 路徑、PowerShell Core
[confirm]     → 顯示設定摘要，等待確認 (Y/N)
[deployESXi]  → 部署 4 台 Nested ESXi VM，加 vmnic2/3，設 vCPU/RAM/Disk
[deployInst]  → 部署 VCF Installer VM (取代 Cloud Builder)
[moveVMs]     → 建立 vApp，移動所有 VM 進去
[generateJson]→ 產生 vcf9-m01-config.json
```

**輸出**

- `vcf9-m01-config.json` — VCF bringup 設定檔（需接著跑 `vcf9-bringup.ps1`）
- `vcf9-m01-deployment.log` — 詳細部署 log

**關鍵設定（在腳本頂端修改）**

```powershell
$VMDatastore  = "vsanDatastore"   # 存放 Nested VM 的 datastore
$VMCluster    = "Cluster"         # 部署目標 cluster
$VMNetwork    = "Trunk-Nobinding" # Nested VM 使用的 portgroup
$NestedESXivMEM  = "96"           # 每台 ESXi RAM (GB)，建議 ≥ 96
$NestedESXivCPU  = "12"           # 每台 ESXi vCPU
```

---

### 2. `vcf9-bringup.ps1` — VCF9 Bringup 提交與監控

**用途**：在 Nested ESXi VM 開機後，自動提交 JSON 到 VCF Installer，並持續監控部署進度。

> **注意**：必須先執行 `autodeployvcf9m01.ps1` 且 VM 全部開機後才能執行。

**執行方式（基本）**

```powershell
pwsh -File .\vcf9-bringup.ps1
```

**執行方式（指定 JSON）**

```powershell
pwsh -File .\vcf9-bringup.ps1 -JsonFile "vcf9-m01-config.json" -InstallerIP "10.0.1.4"
```

**執行方式（只提交，不監控）**

```powershell
pwsh -File .\vcf9-bringup.ps1 -MonitorProgress $false
```

**參數說明**

| 參數 | 預設值 | 說明 |
|------|--------|------|
| `-JsonFile` | `vcf9-m01-config.json` | bringup 設定 JSON |
| `-InstallerIP` | `10.0.1.4` | VCF Installer IP |
| `-InstallerAdminUsername` | `admin@local` | VCF Installer 帳號 |
| `-InstallerAdminPassword` | `VMw@re123!PSO777` | VCF Installer 密碼 |
| `-SkipThumbprintValidation` | `$true` | 跳過 ESXi SSL 憑證驗證 |
| `-SkipGatewayPingValidation` | `$true` | 跳過 Gateway Ping 驗證 |
| `-MonitorProgress` | `$true` | 持續輪詢部署狀態 |
| `-PollIntervalSec` | `120` | 輪詢間隔（秒）|
| `-InstallerReadyTimeoutSec` | `1800` | 等待 Installer ready 逾時（秒）|

**執行流程**

```
[patch JSON]  → 自動注入 skipEsxThumbprintValidation / skipGatewayPingValidation
[wait ready]  → 輪詢 GET /v1/system/appliance-info，等 Installer API ready
[get token]   → POST /v1/tokens，取得 JWT
[submit]      → POST /v1/sddcs，提交 vcf9-m01-config-patched.json
[monitor]     → 每 120 秒輪詢 GET /v1/sddcs，直到 COMPLETED/FAILED
```

**輸出**

- `vcf9-bringup.log` — 詳細 log
- `vcf9-m01-config-patched.json` — 含 skip flag 的修補版 JSON
- Bringup 進度也可從瀏覽器查看：`https://10.0.1.4/vcf-installer-ui/portal/progress-viewer`

---

### 2b. `autodeployvcf91m01.ps1` / `autodeployvcf91m02.ps1` / `autodeployvcf91m03.ps1` — VCF 9.1 部署（透過 9.0.2 + LCM 升級）

**為何不直接用 9.1 OVA**：目前 Broadcom 只釋出 SDDC Manager 9.1 的 OVA（`E:\9.1\VCF-SDDC-Manager-Appliance-9.1.0.0.25371088.ova`），尚無 Nested ESXi 9.1 OVA。Lab 端要拿到 9.1 必須走「先 9.0.2 → SDDC Manager LCM 升級」路徑。

**與 `autodeployvcf9m01.ps1` 差異**

| 項目 | `autodeployvcf9m01.ps1` | `autodeployvcf91m01.ps1` |
|------|------------------------|--------------------------|
| Nested ESXi OVA | 9.0.2 | 9.0.2（相同） |
| VCF Installer OVA | SDDC Mgr 9.0.1.0 | SDDC Mgr 9.0.2.0（較新） |
| 目標版本 | 9.0.2 | 9.1（部署後升級） |
| IP / Hostname | M01（10.0.1.10–13） | 同 M01，會取代既有部署 |

**M01 / M02 / M03 IP 對照**

| Variant | Nested ESXi | SDDC Manager | VCF Installer |
|---------|-------------|--------------|---------------|
| `autodeployvcf91m01.ps1` | 10.0.1.10–13 | 10.0.1.5 | 10.0.1.4 |
| `autodeployvcf91m02.ps1` | 10.0.1.14–17 | 10.0.1.18 | 10.0.1.4 |
| `autodeployvcf91m03.ps1` | 10.0.1.50–53 | 10.0.1.56 | 10.0.1.4 |

> 三組都跟原本 9.0 m01/m02/m03 用相同 IP，是「取代」既有環境的概念。

**完整 9.1 部署流程**

```
Step 1  pwsh -File .\autodeployvcf91m0X.ps1       # X = 1 / 2 / 3，部署 9.0.2 VM
Step 2  等 Nested ESXi 開機
Step 3  pwsh -File .\vcf9-bringup.ps1             # 9.0.2 bringup
Step 4  上傳 9.1 SDDC Mgr bundle 到 SDDC Manager LCM
        → SDDC Manager UI → Lifecycle Management → Bundle Management
        → 或用 API: sddc_manager_api POST /v1/bundles
Step 5  在 SDDC Manager 跑 Upgrade Workflow（9.0.2 → 9.1）
Step 6  vCenter / ESXi / NSX bundle 等 Broadcom 釋出後再分階段升級
```

> **注意**：目前手上只有 SDDC Manager 9.1 OVA。vCenter / ESXi / NSX 的 9.1 bundle 需要另外從 Broadcom Support Portal 取得才能跑完整 LCM 升級。

---

### 3. `autodeployvcfm02.ps1` — VCF 5.x M02 Workload Domain VM 部署

**用途**：部署 VCF 5.2 Workload Domain 的 Nested ESXi VM，使用舊版 Cloud Builder 架構。

> 這是獨立的 M02 部署，使用不同的 IP 範圍（10.0.1.14–17）與 VCF 5.x 版本。

**執行方式**

```powershell
pwsh -File .\autodeployvcfm02.ps1
```

**與 M01 的差異**

| 項目 | M01 (VCF9) | M02 (VCF 5.x) |
|------|-----------|---------------|
| 部署工具 | VCF Installer OVA | Cloud Builder OVA |
| ESXi IP | 10.0.1.10–13 | 10.0.1.14–17 |
| SDDC Manager IP | 10.0.1.5 | 另行設定 |
| vCenter IP | 10.0.1.9 | 10.0.1.19 |
| NSX VIP | — | 10.0.1.21 |
| License | 不需要 (lab) | 需要填入 |

---

### 4. `vcf-lab-mcp-server.py` — Claude AI Lab 操作工具

**位置**：運行於 Ubuntu 10.0.0.65，Port 7000（HTTPS，自簽憑證）

**用途**：讓 Claude Code / Claude Desktop 直接存取 lab，即時 SSH、查 API。

**可用工具**

| 工具 | 說明 | 範例 |
|------|------|------|
| `ssh_exec` | SSH 執行指令到任何 lab 機器 | 查 ESXi log、檢查服務狀態 |
| `get_ssl_thumbprint` | 取得 SSL 憑證 SHA-256 thumbprint | 給 VCF bringup 用 |
| `vcenter_api` | vCenter REST API | 查 cluster、host、datastore |
| `vcf_installer_api` | VCF Installer REST API | 查 bringup 狀態、depot 設定 |
| `sddc_manager_api` | SDDC Manager REST API | 查 domain、host、task |
| `check_dns` | 驗證 DNS 解析 | 確認 FQDN 建好了 |
| `ping_host` | Ping 主機 | 確認網路可達 |
| `vcf_version` | 偵測某 host 是 VCF 9.0 / 9.1 / vCenter 版本 | 判斷 M01 目前跑哪個版本 |
| `list_environments` | 列出所有已知 lab 環境（M01–M03 + VCF5.x） | 給 Claude 一份 IP/版本對照表，`probe=True` 還會即時偵測 |

> 任何 `*_api` 工具都接受 IP 參數，所以同一個 SDDC Manager IP 升級到 9.1 之後不用改 server — 直接呼叫，回傳就是 9.1 的 API 結果。需要明確判斷時用 `vcf_version`。

**Server 安全機制**

| 項目 | 設定 |
|------|------|
| 傳輸 | HTTPS（自簽憑證，`/opt/vcf-mcp/cert.pem` + `key.pem`） |
| 認證 | Bearer token 或 `?api_key=` query string，二者擇一 |
| Keys 來源 | `/opt/vcf-mcp/keys.json`（chmod 600，不入 git） |
| DNS rebinding | 已關閉（允許 IP 直連） |

**服務管理（在 10.0.0.65 上）**

```bash
systemctl status vcf-mcp     # 查看狀態
systemctl restart vcf-mcp    # 重啟（改 keys.json 後要做）
journalctl -u vcf-mcp -f     # 看即時 log
```

**新增/刪除 coworker key**

```bash
# 1. 產生新 key
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 2. 編輯 keys.json
nano /opt/vcf-mcp/keys.json
# {
#   "admin":   "...",
#   "cowork1": "...",
#   "newuser": "<剛產生的 key>"
# }

# 3. 重啟服務
systemctl restart vcf-mcp
```

---

## Claude 用戶端設定（連到 MCP server）

### 共用：自簽憑證信任

Claude Code（VS Code / CLI）與 Claude Desktop 都用 Node.js / Chromium 自己的 TLS stack，不讀 Windows 憑證庫。任選一種：

**Option A — 設環境變數加入信任的 CA**（推薦，較安全）
```powershell
# Windows PowerShell（永久使用者層級）
[Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'C:\path\to\cert.pem', 'User')
```

**Option B — 跳過所有 TLS 驗證**（lab 用，快但較鬆）
```powershell
[Environment]::SetEnvironmentVariable('NODE_TLS_REJECT_UNAUTHORIZED', '0', 'User')
```

或寫在專案的 `.claude/settings.local.json`：
```json
{
  "env": { "NODE_TLS_REJECT_UNAUTHORIZED": "0" }
}
```

設完後**完全重啟** Claude（不是 `/clear`，是整個程式關掉重開）。

---

### 用戶端 A — VS Code Claude Code 擴充

在專案根目錄建 `.mcp.json`：
```json
{
  "mcpServers": {
    "vcf-lab": {
      "type": "sse",
      "url": "https://10.0.0.65:7000/sse",
      "headers": {
        "Authorization": "Bearer <你的 token，從 admin 拿>"
      }
    }
  }
}
```

首次啟動 Claude Code 會跳「核准專案 MCP server」對話框 → 選 Approve。如果之前拒絕過，用 `claude mcp reset-project-choices` 重置。

### 用戶端 B — Claude Code CLI

讀同一個 `.mcp.json`。或用 CLI 指令新增：
```bash
claude mcp add --transport sse vcf-lab "https://10.0.0.65:7000/sse" \
  --header "Authorization: Bearer <你的 token>"
```

驗證：
```bash
claude mcp list                # 應該看到 vcf-lab: ✓ Connected
claude mcp get vcf-lab
```

### 用戶端 C — Claude Desktop App

編輯 config（Windows 路徑）：
```
%APPDATA%\Claude\claude_desktop_config.json
```

```json
{
  "mcpServers": {
    "vcf-lab": {
      "type": "sse",
      "url": "https://10.0.0.65:7000/sse?api_key=<你的 token>"
    }
  }
}
```

> Desktop App 不一定支援 `headers` 欄位，所以這邊用 `?api_key=` query string（server 端兩種都接受）。

### 用戶端 D — claude.ai 雲端（網頁版）

**❌ 不能直連內網。** 10.0.0.65 是內網 IP，Anthropic 後端穿不進來。要從雲端用必須暴露公網（ngrok / Cloudflare Tunnel），目前 lab 設計不走這條路。

---

## 完整部署流程

```
Step 1  設定 DNS（在 10.0.0.200）
        → 確認所有 VCF FQDN 都有 A record

Step 2  執行 VM 部署
        pwsh -File .\autodeployvcf9m01.ps1
        → 約 20–40 分鐘，產生 vcf9-m01-config.json

Step 3  等待 Nested ESXi VM 開機
        → 約 5–10 分鐘（可看 vCenter 確認 VM Power On）

Step 4  執行 VCF Bringup
        pwsh -File .\vcf9-bringup.ps1
        → 自動等 VCF Installer ready → 提交 JSON → 監控部署
        → 總計約 2–4 小時

Step 5  驗證
        → 瀏覽器開 https://10.0.1.5（SDDC Manager）
        → 或請 Claude 用 sddc_manager_api 查詢狀態
```

---

## 常見問題

### VCF Installer API 回傳 401

Token 過期（每次 `vcf9-bringup.ps1` 會自動重新取 token）。如果手動操作，先執行：
```powershell
POST https://10.0.1.4/v1/tokens
Body: {"username":"admin@local","password":"VMw@re123!PSO777"}
```

### Bringup 卡在 validation 失敗

1. 確認 DNS：所有 VCF FQDN 在 10.0.0.200 的 DNS 都有解析
2. 確認 NTP：所有 Nested ESXi 的時間同步正常
3. 開瀏覽器看詳細錯誤：`https://10.0.1.4/vcf-installer-ui/portal/progress-viewer`
4. 或請 Claude：`vcf_installer_api("GET", "/v1/sddcs")` 看狀態

### Nested ESXi 開機後無法 SSH

確認：
- `$VMNetwork` portgroup 的 VLAN 設定正確
- vSwitch 有開啟 Promiscuous Mode / Forged Transmits / MAC Learning

### MCP Server 無回應

```bash
ssh root@10.0.0.65
systemctl restart vcf-mcp
journalctl -u vcf-mcp -n 50
```

### `claude mcp list` 顯示 vcf-lab ✗ Failed to connect

依下列順序排查：

1. **Server 是否在跑**：`ssh root@10.0.0.65 'systemctl is-active vcf-mcp'` → 應為 `active`
2. **本機能否 TCP 連到**：`Test-NetConnection 10.0.0.65 -Port 7000` → `True`
3. **TLS 信任**：上面「自簽憑證信任」那段做了嗎？做完要**完全重啟** Claude
4. **看 server log**：`ssh root@10.0.0.65 'journalctl -u vcf-mcp -n 50 --no-pager'`
   - `Request validation failed` → DNS rebinding 防護（server 端已關閉，若回滾要再關）
   - `Unauthorized` → token 錯誤，檢查 `.mcp.json` 的 Bearer 或 query string
5. **核准狀態**：`claude mcp reset-project-choices` → 重啟 → 對話框出現時選 Approve

### `claude mcp list` 顯示 ✓ Connected 但工具列表還沒出現

目前 Claude session 是進程啟動時就 freeze tool list。**完全結束** Claude（exit / 關掉 VS Code window）→ 重開 → 新 session 才會載入。

---

## 檔案清單

```
VCF9/vcf9autodeploy/
├── autodeployvcf9m01.ps1         # VCF9 M01 VM 部署（主腳本，勿修改）
├── autodeployvcf91m01.ps1        # VCF9.1 部署 M01（10.0.1.10–13）— 走 9.0.2 + LCM
├── autodeployvcf91m02.ps1        # VCF9.1 部署 M02（10.0.1.14–17）— 走 9.0.2 + LCM
├── autodeployvcf91m03.ps1        # VCF9.1 部署 M03（10.0.1.50–53）— 走 9.0.2 + LCM
├── autodeployvcfm02.ps1          # VCF5.x M02 VM 部署（主腳本，勿修改）
├── vcf9-bringup.ps1              # VCF9 bringup 提交與監控
├── vcf-lab-mcp-server.py         # Claude AI MCP 工具 server
├── setup-mcp-ubuntu.sh           # MCP server Ubuntu 安裝腳本
├── cert.pem                      # MCP server 自簽憑證（公開，可發給 coworker）
├── .mcp.json.example             # Claude 用戶端設定範本（複製成 .mcp.json 並填 token）
├── .claude/settings.local.json   # 個人 Claude 設定（gitignore）
├── vcf9-m01-config.json          # 產生的 bringup JSON（執行後出現，gitignore）
├── vcf9-bringup.log              # bringup log（gitignore）
└── README.md                     # 本文件
```

**Ubuntu 端（不在 git）**
```
/opt/vcf-mcp/
├── vcf-lab-mcp-server.py    # 從本 repo 部署上去
├── cert.pem  + key.pem      # 自簽憑證
└── keys.json                # API key 設定（chmod 600，含實際 token）
```
