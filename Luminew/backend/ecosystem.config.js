module.exports = {
  apps: [
    {
      name: "luminew-backend",
      script: "python",
      args: "main.py",
      cwd: "./",
      interpreter: "python",
      watch: false,
      max_memory_restart: "2G",
      env: {
        NODE_ENV: "production",
        PORT: 8000
      },
      log_date_format: "YYYY-MM-DD HH:mm Z",
      error_file: "./logs/pm2-error.log",
      out_file: "./logs/pm2-out.log",
      merge_logs: true,
      autorestart: true,
      restart_delay: 4000
    }
  ]
};
