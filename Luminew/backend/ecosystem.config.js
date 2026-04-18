module.exports = {
  apps: [
    {
      name: "luminew-backend",
      script: "main.py",
      cwd: "C:/Users/Luminew/Desktop/Luminew/Luminew/Luminew/backend",
      interpreter: "C:/Users/Luminew/Desktop/Luminew/Luminew/Luminew/backend/luminew_env/Scripts/pythonw.exe",
      watch: ["main.py", "app"], // 監控代碼變動，一旦您同步代碼就會自動重啟
      ignore_watch: ["logs", "static", ".env", "**/__pycache__"], // 絕對要無視日誌與影片資料夾，避免無限重啟
      max_memory_restart: "2G",
      env: {
        NODE_ENV: "production",
        PYTHONIOENCODING: "utf-8",
        PORT: 8000
      },
      log_date_format: "YYYY-MM-DD HH:mm Z",
      error_file: "./logs/pm2-error.log",
      out_file: "./logs/pm2-out.log",
      merge_logs: true,
      autorestart: true,
      restart_delay: 2000
    }
  ]
};
