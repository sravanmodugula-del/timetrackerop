
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

# Get the script's directory and determine source path
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourcePath = Split-Path -Parent (Split-Path -Parent $ScriptPath)  # Go up two levels to get project root

Write-Host "📂 Script path: $ScriptPath" -ForegroundColor Yellow
Write-Host "📂 Source path: $SourcePath" -ForegroundColor Yellow
Write-Host "📂 Install path: $InstallPath" -ForegroundColor Yellow

# Verify source path exists and contains required files
if (!(Test-Path $SourcePath)) {
    Write-Host "❌ Source path not found: $SourcePath" -ForegroundColor Red
    Write-Host "💡 Make sure to run this script from the fmb-onprem/scripts directory" -ForegroundColor Yellow
    exit 1
}

# Verify critical source files exist
$RequiredSourceFiles = @("package.json", "server", "client", "shared")
foreach ($file in $RequiredSourceFiles) {
    $sourceFile = Join-Path $SourcePath $file
    if (!(Test-Path $sourceFile)) {
        Write-Host "❌ Required source file/directory missing: $sourceFile" -ForegroundColor Red
        exit 1
    }
}

# Create install directory if it doesn't exist
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy application files excluding unnecessary directories
$ExcludeItems = @('.git', 'node_modules', 'dist', '.replit', '.vscode', '.idea', 'logs')
Write-Host "📋 Copying application files..." -ForegroundColor Yellow

Get-ChildItem -Path $SourcePath -Exclude $ExcludeItems | ForEach-Object {
    $destPath = Join-Path $InstallPath $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Path $_.FullName -Destination $destPath -Recurse -Force
    } else {
        Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
    Write-Host "  ✅ Copied: $($_.Name)" -ForegroundColor Green
}

# Store original location and set working directory to install path
$OriginalLocation = Get-Location
Set-Location $InstallPath
Write-Host "📍 Working directory set to: $InstallPath" -ForegroundColor Yellow

# Install application dependencies
Write-Host "📦 Installing application dependencies..." -ForegroundColor Yellow
try {
    npm install --production
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Set up environment configuration
$EnvTemplatePath = "$InstallPath\fmb-onprem\.env.fmb-onprem"
$EnvPath = "$InstallPath\.env"

Write-Host "🔧 Setting up environment configuration..." -ForegroundColor Yellow

if (Test-Path $EnvTemplatePath) {
    if (!(Test-Path $EnvPath)) {
        Copy-Item -Path $EnvTemplatePath -Destination $EnvPath
        Write-Host "✅ Environment template copied to .env" -ForegroundColor Green
        Write-Host "📝 Please edit $EnvPath with your specific configuration" -ForegroundColor Yellow
    } else {
        Write-Host "📝 Environment file already exists: $EnvPath" -ForegroundColor Green
        Write-Host "📝 You may want to review and update it with new settings from the template" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Environment template not found at: $EnvTemplatePath" -ForegroundColor Yellow
    Write-Host "⚠️ Creating basic .env file..." -ForegroundColor Yellow
    
    $BasicEnvContent = @"
# FMB TimeTracker On-Premises Configuration
FMB_DEPLOYMENT=onprem
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database Configuration (Update these values)
FMB_DB_SERVER=HUB-SQL1TST-LIS
FMB_DB_NAME=timetracker
FMB_DB_USER=timetracker
FMB_DB_PASSWORD=YOUR_PASSWORD_HERE
FMB_DB_PORT=1433
FMB_DB_ENCRYPT=true
FMB_DB_TRUST_CERT=true

# SAML Configuration (Update these values)
FMB_SAML_ENTITY_ID=https://timetracker.fmb.com
FMB_SAML_SSO_URL=https://rsa.fmb.com/saml/sso
FMB_SAML_ACS_URL=https://timetracker.fmb.com/saml/acs
FMB_SAML_CERTIFICATE=YOUR_CERTIFICATE_HERE

# Session Configuration
FMB_SESSION_SECRET=CHANGE_THIS_TO_A_SECURE_SECRET
"@
    
    Set-Content -Path $EnvPath -Value $BasicEnvContent
    Write-Host "✅ Basic .env file created" -ForegroundColor Green
}

# Verify critical files exist
$CriticalFiles = @("package.json", "fmb-onprem\config\fmb-database.ts", "server\index.ts")
foreach ($file in $CriticalFiles) {
    $filePath = "$InstallPath\$file"
    if (!(Test-Path $filePath)) {
        Write-Host "❌ Critical file missing: $filePath" -ForegroundColor Red
        Write-Host "❌ Installation may be incomplete. Please check source files." -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ Critical files verified" -ForegroundColor Green

# Build application
Write-Host "🔨 Building application..." -ForegroundColor Yellow
try {
    npm run build
    Write-Host "✅ Application built successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to build application" -ForegroundColor Red
    exit 1
}

# Create PM2 ecosystem file with proper Windows path handling
$NormalizedInstallPath = $InstallPath.Replace('\', '/')
$NormalizedLogPath = $LogPath.Replace('\', '/')

$EcosystemContent = @"
module.exports = {
  apps: [{
    name: '$ServiceName',
    script: './dist/server/index.js',
    cwd: '$NormalizedInstallPath',
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
    log_file: '$NormalizedLogPath/combined.log',
    out_file: '$NormalizedLogPath/out.log',
    error_file: '$NormalizedLogPath/error.log',
    time: true,
    merge_logs: true,
    windows_hide: true,
    restart_delay: 5000,
    max_restarts: 10,
    min_uptime: '10s'
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

# Restore original working directory
Set-Location $OriginalLocation
Write-Host "📍 Restored original working directory" -ForegroundColor Yellow
