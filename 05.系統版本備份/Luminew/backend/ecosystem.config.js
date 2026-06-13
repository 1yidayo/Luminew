module.exports = {
  apps: [
    {
      name: "luminew-backend",
      script: "main.py",
      cwd: "C:/Users/Luminew/Desktop/Luminew/Luminew/Luminew/backend",
      interpreter: "C:/Users/Luminew/Desktop/Luminew/Luminew/Luminew/backend/luminew_env/Scripts/pythonw.exe",
      watch: ["main.py", "app"],
      ignore_watch: [
        "logs",
        "static",
        ".env",
        "**/__pycache__",
        "*.pdf",
        "*.wav",
        "*.json",
        "app/public/audio"
      ],
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
    },
    // {
    //   name: "cloudflare-tunnel",
    //   script: "C:/Program Files (x86)/cloudflared/cloudflared.exe",
    //   args: "tunnel --url http://localhost:8000",
    //   autorestart: true
    // }
  ]
};
