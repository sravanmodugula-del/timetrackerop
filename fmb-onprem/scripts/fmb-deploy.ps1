
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

# Check for .env file
Write-Host "🔍 Validating environment configuration..." -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
    Write-Host "⚠️ .env file not found. Checking for .env.fmb-onprem..." -ForegroundColor Yellow
    if (Test-Path "fmb-onprem/.env.fmb-onprem") {
        Copy-Item "fmb-onprem/.env.fmb-onprem" ".env"
        Write-Host "✅ Copied .env.fmb-onprem to .env" -ForegroundColor Green
    } else {
        Write-Host "❌ No environment file found. Please create .env with required configuration." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ Environment file found" -ForegroundColor Green
}

# Stop PM2 processes
Write-Host "⏹️ Stopping application..." -ForegroundColor Yellow
try {
    Set-Location $InstallPath
    npx pm2 stop ecosystem.config.cjs
    Write-Host "✅ Application stopped" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not stop PM2 processes gracefully" -ForegroundColor Yellow
}

# Update application
Write-Host "📦 Installing all dependencies..." -ForegroundColor Yellow
try {
    # Ensure we install all dependencies including dev dependencies
    npm install --include=dev
    Write-Host "✅ All dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Build application
Write-Host "🔨 Building application..." -ForegroundColor Yellow
try {
    npm run build
    
    # Copy FMB on-premises configuration files to dist
    Write-Host "📋 Copying FMB configuration files..." -ForegroundColor Yellow
    if (-not (Test-Path "dist/fmb-onprem")) {
        New-Item -ItemType Directory -Path "dist/fmb-onprem" -Force | Out-Null
        New-Item -ItemType Directory -Path "dist/fmb-onprem/config" -Force | Out-Null
    }
    
    # Build the TypeScript files for on-prem configs
    npx tsc fmb-onprem/config/fmb-env.ts --outDir dist --target es2020 --module es2020 --moduleResolution node --allowSyntheticDefaultImports --esModuleInterop
    npx tsc fmb-onprem/config/fmb-database.ts --outDir dist --target es2020 --module es2020 --moduleResolution node --allowSyntheticDefaultImports --esModuleInterop
    
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

# Skip cleaning dev dependencies to avoid missing Vite plugin errors
Write-Host "📦 Keeping all dependencies for Vite compatibility..." -ForegroundColor Yellow
Write-Host "✅ Dependencies preserved for production build" -ForegroundColor Green

# Health check
Write-Host "🔍 Running configuration health check..." -ForegroundColor Yellow
try {
    $env:FMB_DEPLOYMENT = "onprem"
    $env:NODE_ENV = "production"
    
    # Check if built config exists, otherwise use ts-node for health check
    if (Test-Path "dist/fmb-onprem/config/fmb-env.js") {
        node -e "
        import('./dist/fmb-onprem/config/fmb-env.js').then(config => {
          config.loadFmbOnPremConfig();
          console.log('✅ Configuration valid');
        }).catch(err => {
          console.error('❌ Config error:', err.message);
          process.exit(1);
        });
        " --input-type=module
    } else {
        # Skip detailed health check if TypeScript files not built - basic validation only
        Write-Host "⚠️ Skipping detailed config validation (TypeScript files not in dist)" -ForegroundColor Yellow
        
        # Basic environment variable check
        $requiredVars = @('FMB_SESSION_SECRET', 'FMB_DB_SERVER', 'FMB_DB_NAME')
        $missing = @()
        foreach ($var in $requiredVars) {
            if (-not (Get-ChildItem Env: | Where-Object { $_.Name -eq $var })) {
                $missing += $var
            }
        }
        
        if ($missing.Count -gt 0) {
            Write-Host "❌ Missing required environment variables: $($missing -join ', ')" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✅ Basic environment validation passed" -ForegroundColor Green
    }
    
    Write-Host "✅ Configuration validation completed" -ForegroundColor Green
} catch {
    Write-Host "❌ Configuration validation failed" -ForegroundColor Red
    Write-Host "Please check your .env file and database connection" -ForegroundColor Yellow
    exit 1
}

# Start application
Write-Host "▶️ Starting application..." -ForegroundColor Yellow
try {
    # Check if PM2 is available
    $pm2Version = npx pm2 --version 2>$null
    if (-not $pm2Version) {
        Write-Host "❌ PM2 is not available" -ForegroundColor Red
        Write-Host "Installing PM2 globally..." -ForegroundColor Yellow
        npm install -g pm2
    }
    
    # Start the application
    npx pm2 start ecosystem.config.cjs --env production
    
    # Wait a moment for the process to start
    Start-Sleep -Seconds 3
    
    # Check if the process is running
    $processStatus = npx pm2 jlist | ConvertFrom-Json
    $appProcess = $processStatus | Where-Object { $_.name -eq "fmb-timetracker" }
    
    if ($appProcess -and $appProcess.pm2_env.status -eq "online") {
        Write-Host "✅ Application started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Application failed to start properly" -ForegroundColor Red
        Write-Host "📝 PM2 Status:" -ForegroundColor Yellow
        npx pm2 status
        Write-Host "📝 Recent logs:" -ForegroundColor Yellow
        npx pm2 logs --lines 10
        exit 1
    }
} catch {
    Write-Host "❌ Failed to start application" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📝 PM2 Status:" -ForegroundColor Yellow
    npx pm2 status
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
Write-Host "View status: npx pm2 status" -ForegroundColor White
Write-Host "View logs: npx pm2 logs" -ForegroundColor White
Write-Host "Restart if needed: npx pm2 restart ecosystem.config.cjs" -ForegroundColor White
