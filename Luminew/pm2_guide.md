# Luminew 伺服器部署與 Cloudflare Tunnel 完整指南

本指南整合了 **Namecheap 網域購買**、**Cloudflare DNS 託管**、**Cloudflare Tunnel 內網穿透隧道**、**Python 虛擬環境建置**、**AI 模型權重還原** 以及 **PM2 後端服務管理** 的完整操作流程與注意事項。

---

## 🌐 第一階段：Namecheap 網域購買與防範風控

### 1. 購買網域步驟
1. 前往 [Namecheap 官網](https://www.namecheap.com/) 搜尋欲購買的網域（例如 `luminew.site` 或 `luminew.website`）。
2. 將網域加入購物車並進行結帳（建議開啟免費提供的 WhoisGuard 隱私保護）。

### 2. ⚠️ 風控防範與 Email 驗證（極度重要）
* **ICANN 郵件驗證**：購買後數分鐘內，註冊 Email 會收到 ICANN 的驗證信，**務必點擊信中連結完成驗證**（若 14 天內未驗證，網域會被暫停解析）。
* **風控驗證（Risk Management）**：
  * 若收到標題含有 `Risk Management Team` 或要求驗證付款的信件，請勿忽視！若未在時限內回覆，**訂單會被取消並直接退款**。
  * **台灣信用卡截斷問題處置**：若使用台灣信用卡（如中信）扣款，描述碼可能被銀行截斷。可直接**截圖網銀扣款明細**並回覆信件說明，或致電銀行客服查詢完整國際授權特店名稱。

---

## ☁️ 第二階段：將網域託管轉移至 Cloudflare DNS

為了搭配 Cloudflare Tunnel 並獲得免費的 HTTPS 憑證與高併發防護，需將 DNS 託管轉移至 Cloudflare。

### 1. 在 Cloudflare 新增網站
1. 註冊/登入 [Cloudflare 控制台](https://dash.cloudflare.com/)。
2. 點擊右上角 **「新增網站 (Add a site)」**，輸入您購買的網域（例如 `luminew.website`）。
3. 方案選擇 **「Free (免費方案)」** 即可。

### 2. 修改 Namecheap 的 NameServers (NS)
1. Cloudflare 會自動掃描 DNS，並提供 **2 組 Cloudflare NameServers**（格式類似：`ada.ns.cloudflare.com` 與 `bob.ns.cloudflare.com`）。
2. 登入 Namecheap 控制台 -> 進入 **Domain List** -> 找到您的網域點擊 **Manage**。
3. 找到 **Nameservers** 欄位，將下拉選單從 `Namecheap BasicDNS` 改為 **`Custom DNS`**。
4. 將 Cloudflare 提供的 2 組 NS 網址複製填入並儲存（生效約需 5~30 分鐘）。

---

## 🔒 第三階段：安裝與配置 Cloudflare Tunnel (連通 GPU 伺服器)

Cloudflare Tunnel 可以在不需要公網 IP 與不需要開啟路由器 Port 的情況下，安全地將本機 `localhost:8000` 映射到您的自訂域名。

### 1. 安裝 Cloudflared
1. 前往 [Cloudflare GitHub Release](https://github.com/cloudflare/cloudflared/releases) 下載最新的 `cloudflared-windows-amd64.msi`。
2. 在 GPU 伺服器上雙擊執行安裝。

### 2. 建立與授權 Tunnel (PowerShell 操作)
開啟 PowerShell 執行以下指令：

1. **登入授權**：
   ```powershell
   cloudflared tunnel login
   ```
   *執行後瀏覽器會自動開啟，請選擇剛才導入 Cloudflare 的網域進行授權。授權成功後會自動在 `C:\Users\使用者名稱\.cloudflared\` 生成 `cert.pem`*。

2. **建立隧道**：
   ```powershell
   cloudflared tunnel create luminew-server
   ```
   *建立成功後會印出一組 `Tunnel ID` (UUID 格式)，並生成憑證 JSON 檔。*

3. **綁定網域與 CNAME 路由**：
   ```powershell
   cloudflared tunnel route dns luminew-server api.luminew.website
   ```
   *此指令會自動在 Cloudflare DNS 中新增一條 CNAME 紀錄，將 `api.luminew.website` 指向該隧道。*

### 3. 設定配置文件 (`config.yml`)
在 `C:\Users\您的使用者名稱\.cloudflared\` 目錄下建立一個檔名為 `config.yml` 的檔案，內容如下：

```yaml
tunnel: <您的-Tunnel-ID>
credentials-file: C:\Users\您的使用者名稱\.cloudflared\<您的-Tunnel-ID>.json

ingress:
  - hostname: api.luminew.website
    service: http://localhost:8000
  - service: http_status:404
```

### 4. 啟動與安裝為 Windows 背景服務
1. **測試啟動**：
   ```powershell
   cloudflared tunnel run luminew-server
   ```
   *(確認主機可以正常連通且沒有報錯)*
2. **安裝為 Windows 背景服務（自動開機自啟）**：
   ```powershell
   cloudflared service install
   cloudflared service start
   ```

---

## 🐍 第四階段：Python 虛擬環境 (`luminew_env`) 與 AI 模型還原指南

### 1. 重建 Python 虛擬環境 (`luminew_env`)
在新的 GPU 電腦上記得重新建立專屬的 Python 虛擬環境，步驟如下：

1. 開啟 PowerShell 並切換至 `backend` 目錄：
   ```powershell
   cd C:\Users\您的帳號\Desktop\專案路徑\backend
   ```
2. 執行指令建立名為 `luminew_env` 的虛擬環境：
   ```powershell
   python -m venv luminew_env
   ```
3. 啟用虛擬環境並安裝所需依賴套件：
   ```powershell
   .\luminew_env\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

---

### 2. 🧠 AI 模型權重檔 (`backend/models/test_best_.pth`) 還原說明

* **這個檔案是什麼？**  
  `test_best_.pth` 是本專案後端 **情緒分析服務（`emotion_service.py`）** 所使用的 PyTorch 人臉表情與情緒辨識 AI 模型權重。系統在面試過程中會透過這個模型分析使用者的即時表情與情緒反應。如果缺少這個檔案，面試情緒分析功能將無法運行。

* **如何還原裝回去？**  
  1. 在新電腦的 `backend` 資料夾下，確認是否有 `models` 資料夾（若沒有請手動建立）：
     ```powershell
     mkdir models
     ```
  2. 將備份好的 `test_best_.pth` 複製並貼到 `backend/models/` 目錄內。
  3. 確保最終檔案路徑結構為：
     `backend/models/test_best_.pth`

---

## ⚡ 第五階段：高效開發與測試技巧 (Cloudflare 快取清除)

在開發與測試階段，如果修改了前端靜態資源（如 Web Build）或是 API 回傳內容，有時會因為 Cloudflare 邊緣節點快取了舊檔案而看不到最新效果。

### 快取清除頁面 (Purge Cache)
* **快速連結**：前往 [Cloudflare 快取配置頁面](https://dash.cloudflare.com/ff711edad7a9dca793a50674685615b6/luminew.website/caching/configuration) (路徑：`Caching` -> `Configuration`)。
* **操作方式**：
  * **Purge Everything (清除所有快取)**：當部署了全新的網頁版或大改 API 靜態檔時，點擊此按鈕可強制全球邊緣伺服器清空舊快取並重新抓取最新內容。
  * **Custom Purge (自訂清除)**：若只需清除特定網址（如單一圖片或 JS 檔），可輸入具體 URL 進行精準清除。

---

## 🛠️ 第六階段：PM2 後端服務管理與營運指令

### ⚠️ 換新電腦 / 遷移服務必看注意事項

專案後端使用 `backend/ecosystem.config.js` 作為 PM2 的配置文件。
換到新電腦後，**請務必修改該檔案中的絕對路徑**：

```javascript
module.exports = {
  apps: [
    {
      name: "luminew-backend",
      script: "main.py",
      // 1. 修改為新電腦上專案 backend 目錄的實際路徑
      cwd: "C:/Users/新使用者名稱/Desktop/.../backend",
      // 2. 修改為新電腦上 Python 虛擬環境中 pythonw.exe 的實際路徑
      interpreter: "C:/Users/新使用者名稱/Desktop/.../backend/luminew_env/Scripts/pythonw.exe",
      ...
    }
  ]
};
```

### 🚀 常用 PM2 指令總整理

#### 1. 服務啟動與狀態查詢
* **啟動後端服務** (需先切換至 `backend` 目錄)：
  ```powershell
  cd backend
  pm2 start ecosystem.config.js
  ```
* **查看目前所有服務狀態列表**：
  ```powershell
  pm2 list
  # 或簡寫
  pm2 status
  ```
* **開啟即時儀表板**（視覺化監控 CPU / 記憶體使用率）：
  ```powershell
  pm2 monit
  ```

#### 2. 日誌 (Log) 查詢與維護
* **即時查看後端輸出 Log** (包含即時 Print 與報錯訊息)：
  ```powershell
  pm2 logs luminew-backend
  ```
* **查看指定行數的舊 Log** (例如最後 100 行)：
  ```powershell
  pm2 logs luminew-backend --lines 100
  ```
* **清空累積的 Log 紀錄** (釋放硬碟空間)：
  ```powershell
  pm2 flush
  ```
* **重啟後端服務** (修改程式碼後手動重啟)：
  ```powershell
  pm2 restart luminew-backend
  ```

#### 3. 停止與刪除服務
* **暫時停止後端服務**：
  ```powershell
  pm2 stop luminew-backend
  ```
* **從 PM2 列表中完全移除該服務**：
  ```powershell
  pm2 delete luminew-backend
  ```

#### 4. PM2 電腦開機自動啟動設定 (Windows 環境)
1. **保存當前正在運行的 PM2 服務狀態**：
   ```powershell
   pm2 save
   ```
2. **安裝 Windows 自動開機啟動服務** (需管理員權限)：
   ```powershell
   npm install -g pm2-windows-startup
   pm2-startup install
   pm2 save
   ```

---

## 📋 新電腦上線完整速查清單 (Checklist)

1. **程式碼與環境**：`git clone` 專案，放回 `backend/.env` 檔與 `backend/models/test_best_.pth`。
2. **建立 Python 虛擬環境**：執行 `python -m venv luminew_env` 並安裝 `pip install -r requirements.txt`。
3. **PM2 路徑修正**：修改 `backend/ecosystem.config.js` 中的 `cwd` 與 `interpreter`。
4. **PM2 啟動**：執行 `cd backend` 並運行 `pm2 start ecosystem.config.js`。
5. **Cloudflare Tunnel 啟動**：安裝 `cloudflared`，確認 `config.yml` 設定並執行 `cloudflared service start`。
6. **高效測試**：發布新版本或修改檔案後，可至 Cloudflare 控制台執行 **Purge Everything** 清除快取以確保即時生效。
7. **更新前端 Config**：確定 Flutter App `lib/config.dart` 中的 API 網址更新為 `https://luminew.website`！