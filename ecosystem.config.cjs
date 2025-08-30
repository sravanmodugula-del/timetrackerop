
module.exports = {
  apps: [{
    name: 'FMBTimeTracker',
    script: './dist/server/index.js',
    cwd: 'C:/fmb-timetracker',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      HOST: '0.0.0.0',
      FMB_DEPLOYMENT: 'onprem'
    },
    instances: 1,
    exec_mode: 'cluster',
    watch: false,
    max_memory_restart: '1G',
    log_file: 'C:/fmb-timetracker/logs/combined.log',
    out_file: 'C:/fmb-timetracker/logs/out.log',
    error_file: 'C:/fmb-timetracker/logs/error.log',
    time: true,
    merge_logs: true,
    windows_hide: true,
    restart_delay: 5000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
