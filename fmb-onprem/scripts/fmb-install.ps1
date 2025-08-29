
# FMB TimeTracker On-Premises Installation Script for Windows Server 2022
# This script sets up the complete on-premises environment on Windows

param(
    [string]$InstallPath = "C:\fmb-timetracker",
    [string]$ServiceName = "FMBTimeTracker",
    [string]$ServiceUser = "NetworkService"
)

Write-Host "🏢 FMB TimeTracker On-Premises Installation (Windows Server 2022)" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Create application directories
Write-Host "📁 Creating application directories..." -ForegroundColor Yellow
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force
    Write-Host "✅ Created directory: $InstallPath" -ForegroundColor Green
}

$LogPath = "$InstallPath\logs"
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force
    Write-Host "✅ Created log directory: $LogPath" -ForegroundColor Green
}

# Check if Node.js is installed
Write-Host "🔍 Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js is installed: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js is not installed. Please install Node.js 20.x or higher from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Install PM2 globally
Write-Host "🔧 Installing PM2..." -ForegroundColor Yellow
try {
    npm install -g pm2
    npm install -g pm2-windows-service
    Write-Host "✅ PM2 installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install PM2" -ForegroundColor Red
    exit 1
}

# Copy application files
Write-Host "📋 Copying application files..." -ForegroundColor Yellow
$SourcePath = Get-Location
Copy-Item -Path "$SourcePath\*" -Destination $InstallPath -Recurse -Force -Exclude @('.git', 'node_modules', 'dist')
Write-Host "✅ Application files copied" -ForegroundColor Green

# Set working directory
Set-Location $InstallPath

# Install application dependencies
Write-Host "📦 Installing application dependencies..." -ForegroundColor Yellow
try {
    npm install --production
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Copy environment file if it doesn't exist
if (!(Test-Path "$InstallPath\.env")) {
    Copy-Item -Path "$InstallPath\fmb-onprem\.env.fmb-onprem" -Destination "$InstallPath\.env"
    Write-Host "📝 Environment template copied to .env - Please configure your settings" -ForegroundColor Yellow
}

# Build application
Write-Host "🔨 Building application..." -ForegroundColor Yellow
try {
    npm run build
    Write-Host "✅ Application built successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to build application" -ForegroundColor Red
    exit 1
}

# Create PM2 ecosystem file
$EcosystemContent = @"
module.exports = {
  apps: [{
    name: '$ServiceName',
    script: 'dist/index.js',
    cwd: '$InstallPath',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      FMB_DEPLOYMENT: 'onprem'
    },
    instances: 1,
    exec_mode: 'cluster',
    watch: false,
    max_memory_restart: '1G',
    log_file: '$LogPath\\combined.log',
    out_file: '$LogPath\\out.log',
    error_file: '$LogPath\\error.log',
    time: true,
    merge_logs: true,
    windows_hide: true
  }]
};
"@

Set-Content -Path "$InstallPath\ecosystem.config.js" -Value $EcosystemContent
Write-Host "✅ PM2 ecosystem configuration created" -ForegroundColor Green

# Install PM2 as Windows service
Write-Host "🔧 Installing PM2 as Windows service..." -ForegroundColor Yellow
try {
    pm2-service-install -n $ServiceName
    Write-Host "✅ PM2 service installed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ PM2 service installation may have issues - check manually" -ForegroundColor Yellow
}

# Set up Windows Firewall rule for port 3000
Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "FMB TimeTracker" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
    Write-Host "✅ Firewall rule created for port 3000" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Failed to create firewall rule - configure manually if needed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ FMB TimeTracker installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit $InstallPath\.env with your configuration" -ForegroundColor White
Write-Host "2. Run the database setup script on your MS SQL Server (HUB-SQL1TST-LIS)" -ForegroundColor White
Write-Host "3. Configure IIS reverse proxy on HUB-DEVAPP01-C3" -ForegroundColor White
Write-Host "4. Start the application: pm2 start ecosystem.config.js" -ForegroundColor White
Write-Host "5. View logs: pm2 logs" -ForegroundColor White
Write-Host "6. Check status: pm2 status" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Service Management:" -ForegroundColor Cyan
Write-Host "Start service: net start $ServiceName" -ForegroundColor White
Write-Host "Stop service: net stop $ServiceName" -ForegroundColor White
Write-Host "Restart service: net stop $ServiceName && net start $ServiceName" -ForegroundColor White
