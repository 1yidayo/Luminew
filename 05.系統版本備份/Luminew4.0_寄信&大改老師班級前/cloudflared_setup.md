# Cloudflare Tunnel 配置指南 (Luminew 專用)

為了確保 50 人內測時的連線穩定性，我們將使用 Cloudflare Tunnel 取代 Ngrok。

## 1. 安裝 Cloudflared

### Windows (GPU 伺服器)
1. 前往 [Cloudflare 官網](https://github.com/cloudflare/cloudflared/releases) 下載最新的 `cloudflared-windows-amd64.msi`。
2. 執行安裝程式完成安裝。

## 2. 啟動臨時通道 (Quickstart)

在伺服器終端機執行以下指令：

```powershell
cloudflared tunnel --url http://localhost:8000
```

### 注意事項
- 執行後，終端機會輸出一組網址（例如：`https://random-word-pair.trycloudflare.com`）。
- **請務必將此網址更新至 Flutter App 的 `lib/config.dart` 中。**
- 臨時通道在關閉終端機或重啟服務後，網址會改變。

## 3. 持久化配置 (推薦正式測試時使用)

如果您希望擁有固定的域名，請依照以下步驟操作：

1. **登入**：
   ```powershell
   cloudflared tunnel login
   ```
2. **創建隧道**：
   ```powershell
   cloudflared tunnel create luminew-server
   ```
3. **配置路由** (假設您有無公網 IP 的域名)：
   ```powershell
   cloudflared tunnel route dns luminew-server api.yourdomain.com
   ```
4. **啟動**：
   ```powershell
   cloudflared tunnel run luminew-server
   ```

## 4. 優點總結
- **無限流量**：不像 Ngrok 免費版有限制。
- **高併發**：支撐 50 人同時連線不塞車。
- **原生 HTTPS**：解決 WebRTC 必須在安全來源運行的問題，且排除 D-ID Webhook 被攔截的風險。
