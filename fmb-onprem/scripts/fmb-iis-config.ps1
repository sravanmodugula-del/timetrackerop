
# FMB TimeTracker IIS Reverse Proxy Configuration
# Configures IIS on Windows Server 2022 to proxy requests to Node.js application

param(
    [string]$SiteName = "timetracker.fmb.com",
    [string]$ApplicationPool = "FMBTimeTrackerPool",
    [int]$NodePort = 3000
)

Write-Host "🌐 FMB TimeTracker IIS Configuration" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

# Import WebAdministration module
Import-Module WebAdministration

# Install required IIS features
Write-Host "🔧 Installing required IIS features..." -ForegroundColor Yellow
$features = @(
    "IIS-WebServerRole",
    "IIS-WebServer",
    "IIS-CommonHttpFeatures",
    "IIS-HttpRedirect",
    "IIS-HttpErrors",
    "IIS-StaticContent",
    "IIS-DefaultDocument",
    "IIS-DirectoryBrowsing",
    "IIS-ASPNET45",
    "IIS-NetFxExtensibility45",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",
    "IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",
    "IIS-ApplicationDevelopment"
)

foreach ($feature in $features) {
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
    } catch {
        Write-Host "⚠️ Could not enable feature: $feature" -ForegroundColor Yellow
    }
}

# Install URL Rewrite Module (required for reverse proxy)
Write-Host "📦 Installing URL Rewrite Module..." -ForegroundColor Yellow
$urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
$tempPath = "$env:TEMP\urlrewrite.msi"

try {
    Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $tempPath
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$tempPath`" /quiet"
    Remove-Item $tempPath -Force
    Write-Host "✅ URL Rewrite Module installed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ URL Rewrite Module installation may have failed - install manually if needed" -ForegroundColor Yellow
}

# Create Application Pool
Write-Host "🏊 Creating Application Pool: $ApplicationPool..." -ForegroundColor Yellow
if (Get-IISAppPool -Name $ApplicationPool -ErrorAction SilentlyContinue) {
    Remove-WebAppPool -Name $ApplicationPool
}

New-WebAppPool -Name $ApplicationPool
Set-ItemProperty -Path "IIS:\AppPools\$ApplicationPool" -Name processModel.identityType -Value ApplicationPoolIdentity
Set-ItemProperty -Path "IIS:\AppPools\$ApplicationPool" -Name recycling.periodicRestart.time -Value "00:00:00"
Write-Host "✅ Application Pool created" -ForegroundColor Green

# Create Website
Write-Host "🌍 Creating Website: $SiteName..." -ForegroundColor Yellow
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Remove-Website -Name $SiteName
}

$wwwPath = "C:\inetpub\wwwroot\$SiteName"
if (!(Test-Path $wwwPath)) {
    New-Item -ItemType Directory -Path $wwwPath -Force
}

# Create a simple index.html for health checks
$indexContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>FMB TimeTracker</title>
</head>
<body>
    <h1>FMB TimeTracker - Reverse Proxy Active</h1>
    <p>If you see this page, the IIS reverse proxy is configured but the Node.js application may not be running.</p>
</body>
</html>
"@

Set-Content -Path "$wwwPath\index.html" -Value $indexContent

New-Website -Name $SiteName -Port 80 -PhysicalPath $wwwPath -ApplicationPool $ApplicationPool
Write-Host "✅ Website created" -ForegroundColor Green

# Create web.config with URL Rewrite rules
$webConfigContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="Reverse Proxy to Node.js" stopProcessing="true">
          <match url="(.*)" />
          <conditions>
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="true" />
            <add input="{REQUEST_FILENAME}" matchType="IsDirectory" negate="true" />
          </conditions>
          <action type="Rewrite" url="http://localhost:$NodePort/{R:1}" />
        </rule>
      </rules>
    </rewrite>
    <httpErrors errorMode="Detailed" />
  </system.webServer>
</configuration>
"@

Set-Content -Path "$wwwPath\web.config" -Value $webConfigContent
Write-Host "✅ URL Rewrite rules configured" -ForegroundColor Green

# Set permissions
Write-Host "🔐 Setting permissions..." -ForegroundColor Yellow
$acl = Get-Acl $wwwPath
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl $wwwPath $acl
Write-Host "✅ Permissions set" -ForegroundColor Green

Write-Host ""
Write-Host "✅ IIS configuration completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "Website: $SiteName" -ForegroundColor White
Write-Host "Application Pool: $ApplicationPool" -ForegroundColor White
Write-Host "Physical Path: $wwwPath" -ForegroundColor White
Write-Host "Proxy Target: http://localhost:$NodePort" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Ensure your Node.js application is running on port $NodePort" -ForegroundColor White
Write-Host "2. Test the proxy: http://localhost or http://$SiteName" -ForegroundColor White
Write-Host "3. Configure SSL certificate for HTTPS (if needed)" -ForegroundColor White
Write-Host "4. Update DNS to point timetracker.fmb.com to this server" -ForegroundColor White
