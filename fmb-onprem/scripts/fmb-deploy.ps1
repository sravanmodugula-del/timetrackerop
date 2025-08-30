
# FMB TimeTracker On-Premises Deployment Script for Windows
# Updates the application with new version

param(
    [string]$InstallPath = "C:\fmb-timetracker",
    [string]$ServiceName = "FMBTimeTracker"
)

Write-Host "🚀 FMB TimeTracker Deployment (Windows)" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Create backup
$BackupPath = "$InstallPath-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "💾 Creating backup at $BackupPath..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    Copy-Item -Path $InstallPath -Destination $BackupPath -Recurse -Force
    Write-Host "✅ Backup created" -ForegroundColor Green
}

# Ensure required directories exist
Write-Host "📁 Creating required directories..." -ForegroundColor Yellow
if (-not (Test-Path "$InstallPath\logs")) {
    New-Item -ItemType Directory -Path "$InstallPath\logs" -Force | Out-Null
}
Write-Host "✅ Directories created" -ForegroundColor Green

# Stop PM2 processes
Write-Host "⏹️ Stopping application..." -ForegroundColor Yellow
try {
    Set-Location $InstallPath
    pm2 stop ecosystem.config.js
    Write-Host "✅ Application stopped" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not stop PM2 processes gracefully" -ForegroundColor Yellow
}

# Update application
Write-Host "📦 Installing all dependencies..." -ForegroundColor Yellow
try {
    npm install
    Write-Host "✅ All dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Build application
Write-Host "🔨 Building application..." -ForegroundColor Yellow
try {
    npm run build
    
    # Verify build artifacts exist
    if (-not (Test-Path "dist")) {
        Write-Host "❌ Build directory not found" -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-Path "dist/index.js")) {
        Write-Host "❌ Server build not found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Application built successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Build failed" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Clean up dev dependencies for production
Write-Host "🧹 Cleaning up dev dependencies..." -ForegroundColor Yellow
try {
    npm prune --production
    Write-Host "✅ Dev dependencies removed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not prune dev dependencies" -ForegroundColor Yellow
}

# Health check
Write-Host "🔍 Running configuration health check..." -ForegroundColor Yellow
try {
    $env:FMB_DEPLOYMENT = "onprem"
    $env:NODE_ENV = "production"
    node -e "
    import('./fmb-onprem/config/fmb-env.js').then(config => {
      config.loadFmbOnPremConfig();
      console.log('✅ Configuration valid');
    }).catch(err => {
      console.error('❌ Config error:', err.message);
      process.exit(1);
    });
    " --input-type=module
    Write-Host "✅ Configuration validation passed" -ForegroundColor Green
} catch {
    Write-Host "❌ Configuration validation failed" -ForegroundColor Red
    Write-Host "Please check your .env file and database connection" -ForegroundColor Yellow
    exit 1
}

# Start application
Write-Host "▶️ Starting application..." -ForegroundColor Yellow
try {
    pm2 start ecosystem.config.js
    Write-Host "✅ Application started" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to start application" -ForegroundColor Red
    exit 1
}

# Wait for service to be ready
Write-Host "⏳ Waiting for service to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Verify deployment
Write-Host "🔍 Verifying deployment..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Deployment successful!" -ForegroundColor Green
        Write-Host "🌐 Application is running on port 3000" -ForegroundColor Green
    } else {
        Write-Host "❌ Health check failed - HTTP Status: $($response.StatusCode)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Deployment verification failed" -ForegroundColor Red
    Write-Host "📝 Check application logs: pm2 logs" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "📋 Post-deployment commands:" -ForegroundColor Cyan
Write-Host "View status: pm2 status" -ForegroundColor White
Write-Host "View logs: pm2 logs" -ForegroundColor White
Write-Host "Restart if needed: pm2 restart ecosystem.config.js" -ForegroundColor White
