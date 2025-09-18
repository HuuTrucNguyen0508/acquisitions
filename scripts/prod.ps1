#Requires -Version 7.0

<#
.SYNOPSIS
    Production Environment Management Script for Acquisition App
    
.DESCRIPTION
    This PowerShell script manages the production environment with Docker.
    It provides functions to start, stop, and manage the production containers.
    
.PARAMETER Command
    The command to execute (start, stop, restart, status, logs, shell, migrate, generate, cleanup, help)
    
.PARAMETER Service
    Optional service name for logs and shell commands
    
.EXAMPLE
    .\scripts\prod.ps1 start
    Starts the production environment
    
.EXAMPLE
    .\scripts\prod.ps1 logs app
    Shows logs for the app service
    
.EXAMPLE
    .\scripts\prod.ps1 shell app
    Opens shell in the app container
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "shell", "migrate", "generate", "cleanup", "help", "")]
    [string]$Command = "help",
    
    [Parameter(Position = 1)]
    [string]$Service = ""
)

# Configuration
$ProjectName = "acquisitions"
$ProdComposeFile = "docker-compose.prod.yml"
$EnvFile = ".env.production"

# Color functions for better output
function Write-InfoMessage {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Invoke-DockerCompose {
    param([string[]]$Arguments)
    
    if ($script:ComposeCmd -eq "docker compose") {
        & docker compose @Arguments
    } else {
        & docker-compose @Arguments
    }
}

function Test-Requirements {
    Write-InfoMessage "Checking requirements..."
    
    # Check if Docker is installed and running
    try {
        $dockerInfo = docker info 2>$null
        if (-not $dockerInfo) {
            Write-ErrorMessage "Docker is not running or not accessible"
            Write-InfoMessage "Please start Docker Desktop and try again"
            exit 1
        }
    }
    catch {
        Write-ErrorMessage "Docker is not installed or not in PATH"
        exit 1
    }
    
    # Check if Docker Compose is available
    try {
        $composeVersion = docker compose version 2>$null
        if ($composeVersion) {
            $script:ComposeCmd = "docker compose"
        }
        else {
            $dockerComposeVersion = docker-compose --version 2>$null
            if ($dockerComposeVersion) {
                $script:ComposeCmd = "docker-compose"
            }
            else {
                Write-ErrorMessage "Docker Compose is not installed or not in PATH"
                exit 1
            }
        }
    }
    catch {
        Write-ErrorMessage "Docker Compose is not available"
        exit 1
    }
    
    Write-SuccessMessage "Requirements check passed"
}

function Test-EnvironmentFile {
    if (-not (Test-Path $EnvFile)) {
        Write-ErrorMessage "Environment file $EnvFile not found"
        Write-InfoMessage "Please create $EnvFile with your production environment variables"
        Write-InfoMessage "Required variables: DATABASE_URL, JWT_SECRET, NODE_ENV=production"
        exit 1
    }
    
    # Read and validate environment variables
    $envContent = Get-Content $EnvFile | Where-Object { $_ -match '^[^#]*=' }
    $envVars = @{}
    
    foreach ($line in $envContent) {
        if ($line -match '^([^=]+)=(.*)$') {
            $envVars[$matches[1]] = $matches[2]
        }
    }
    
    # Check required variables
    $requiredVars = @("DATABASE_URL", "JWT_SECRET", "NODE_ENV")
    
    foreach ($var in $requiredVars) {
        if (-not $envVars.ContainsKey($var) -or [string]::IsNullOrWhiteSpace($envVars[$var])) {
            Write-ErrorMessage "$var is not properly set in $EnvFile"
            exit 1
        }
    }
    
    # Verify NODE_ENV is set to production
    if ($envVars["NODE_ENV"] -ne "production") {
        Write-WarningMessage "NODE_ENV should be set to 'production' in $EnvFile"
    }
    
    Write-SuccessMessage "Environment configuration is valid"
}

function Start-ProdEnvironment {
    Write-InfoMessage "🚀 Starting Acquisition App in Production Mode"
    Write-Host "===============================================" -ForegroundColor Cyan
    
    Write-InfoMessage "📦 Building and starting production containers..."
    Write-InfoMessage "   - Using Neon Cloud Database (no local proxy)"
    Write-InfoMessage "   - Running in optimized production mode"
    Write-Host ""
    
    # Build and start services
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "up", "--build", "-d")
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Failed to start production environment"
        exit 1
    }
    
    Write-InfoMessage "⏳ Waiting for services to be healthy..."
    
    # Wait for services to be ready
    $maxAttempts = 30
    $attempt = 1
    $servicesReady = $false
    
    while ($attempt -le $maxAttempts -and -not $servicesReady) {
        Start-Sleep -Seconds 2
        
        try {
            $psOutput = Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "ps")
            if ($psOutput -match "healthy" -or $psOutput -match "running") {
                $servicesReady = $true
                break
            }
        }
        catch {
            # Continue waiting
        }
        
        Write-InfoMessage "Waiting for services to start... (attempt $attempt/$maxAttempts)"
        $attempt++
    }
    
    if (-not $servicesReady) {
        Write-ErrorMessage "Services failed to start within expected time"
        Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "logs")
        exit 1
    }
    
    # Run database migrations
    Write-InfoMessage "📜 Applying latest schema with Drizzle..."
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "exec", "app", "pnpm", "db:migrate")
    
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Database migrations completed successfully"
    }
    else {
        Write-WarningMessage "Database migrations may have failed - check logs"
    }
    
    Write-Host ""
    Write-SuccessMessage "🎉 Production environment started!"
    Write-InfoMessage "   Application: http://localhost:3000"
    Write-InfoMessage "   Nginx (if enabled): http://localhost:80"
    Write-InfoMessage "   Logs: docker logs acquisitions-app-prod"
    Write-Host ""
    Write-InfoMessage "Useful commands:"
    Write-InfoMessage "   View logs: .\scripts\prod.ps1 logs"
    Write-InfoMessage "   Stop app: .\scripts\prod.ps1 stop"
}

function Stop-ProdEnvironment {
    Write-InfoMessage "Stopping production environment..."
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "down")
    Write-SuccessMessage "Production environment stopped"
}

function Restart-ProdEnvironment {
    Write-InfoMessage "Restarting production environment..."
    Stop-ProdEnvironment
    Start-ProdEnvironment
}

function Show-Logs {
    param([string]$ServiceName)
    
    if ($ServiceName) {
        Write-InfoMessage "Showing logs for $ServiceName..."
        Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "logs", "-f", $ServiceName)
    }
    else {
        Write-InfoMessage "Showing logs for all services..."
        Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "logs", "-f")
    }
}

function Show-Status {
    Write-InfoMessage "Production environment status:"
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "ps")
}

function Invoke-Migrations {
    Write-InfoMessage "📜 Running database migrations..."
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "exec", "app", "pnpm", "db:migrate")
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Migrations completed successfully"
    }
    else {
        Write-ErrorMessage "Migration failed"
        exit 1
    }
}

function Invoke-GenerateMigrations {
    Write-InfoMessage "📜 Generating database migrations..."
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "exec", "app", "pnpm", "db:generate")
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Migrations generated successfully"
    }
    else {
        Write-ErrorMessage "Migration generation failed"
        exit 1
    }
}

function Open-ContainerShell {
    param([string]$ServiceName = "app")
    
    Write-InfoMessage "Opening shell in $ServiceName container..."
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "exec", $ServiceName, "sh")
}

function Invoke-Cleanup {
    Write-InfoMessage "🧹 Cleaning up production environment..."
    
    # Stop and remove containers, networks, volumes
    Invoke-DockerCompose -Arguments @("-f", $ProdComposeFile, "down", "-v", "--remove-orphans")
    
    # Remove dangling images
    $danglingImages = docker images -f "dangling=true" -q 2>$null
    if ($danglingImages) {
        Write-InfoMessage "Removing dangling Docker images..."
        docker rmi $danglingImages 2>$null
    }
    
    Write-SuccessMessage "Cleanup completed"
}

function Show-Help {
    Write-Host @"
Production Environment Management Script
========================================

Usage: .\scripts\prod.ps1 [COMMAND] [SERVICE]

Commands:
  start       Start the production environment
  stop        Stop the production environment  
  restart     Restart the production environment
  status      Show status of services
  logs        Show logs (optionally for specific service)
  shell       Open shell in container (default: app)
  migrate     Run database migrations
  generate    Generate database migrations
  cleanup     Stop and clean up all resources
  help        Show this help message

Examples:
  .\scripts\prod.ps1 start                    # Start production environment
  .\scripts\prod.ps1 logs app                 # Show logs for app service
  .\scripts\prod.ps1 shell app                # Open shell in app container
  .\scripts\prod.ps1 migrate                  # Run database migrations

Environment Setup:
  Make sure to configure your .env.production file with:
  - DATABASE_URL: Your production database URL
  - JWT_SECRET: Strong JWT secret for production
  - NODE_ENV: Set to 'production'
  - Other production-specific variables

For more information, see the README.md file.
"@ -ForegroundColor Cyan
}

# Main script logic
switch ($Command.ToLower()) {
    "start" {
        Test-Requirements
        Test-EnvironmentFile
        Start-ProdEnvironment
    }
    "stop" {
        Test-Requirements
        Stop-ProdEnvironment
    }
    "restart" {
        Test-Requirements
        Test-EnvironmentFile
        Restart-ProdEnvironment
    }
    "status" {
        Test-Requirements
        Show-Status
    }
    "logs" {
        Test-Requirements
        Show-Logs -ServiceName $Service
    }
    "shell" {
        Test-Requirements
        Open-ContainerShell -ServiceName $(if ($Service) { $Service } else { "app" })
    }
    "migrate" {
        Test-Requirements
        Invoke-Migrations
    }
    "generate" {
        Test-Requirements
        Invoke-GenerateMigrations
    }
    "cleanup" {
        Test-Requirements
        Invoke-Cleanup
    }
    "help" {
        Show-Help
    }
    "" {
        Show-Help
    }
    default {
        Write-ErrorMessage "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
