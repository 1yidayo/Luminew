module.exports = {
  apps: [{
    name: "LuminewBackend",
    script: "./luminew_env/Scripts/uvicorn.exe",
    args: "app.main:app --host 0.0.0.0 --port 8000",
    cwd: "./",
    env: {
      NODE_ENV: "production",
      PYTHONUTF8: "1"
    }
  }, {
    name: "LuminewTunnel",
    script: "ngrok",
    args: "http --domain=unobviable-oralee-unsicker.ngrok-free.dev 8000",
    exec_mode: "fork"
  }]
}
