#Requires -Version 7.0

<#
.SYNOPSIS
    Development Environment Management Script for Acquisition App with Neon Local
    
.DESCRIPTION
    This PowerShell script manages the development environment with Neon Local and Docker.
    It provides functions to start, stop, and manage the development containers.
    
.PARAMETER Command
    The command to execute (start, stop, restart, status, logs, shell, migrate, generate, studio, cleanup, help)
    
.PARAMETER Service
    Optional service name for logs and shell commands
    
.EXAMPLE
    .\scripts\dev.ps1 start
    Starts the development environment
    
.EXAMPLE
    .\scripts\dev.ps1 logs app
    Shows logs for the app service
    
.EXAMPLE
    .\scripts\dev.ps1 shell neon-local
    Opens shell in the neon-local container
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "shell", "migrate", "generate", "studio", "cleanup", "help", "")]
    [string]$Command = "help",
    
    [Parameter(Position = 1)]
    [string]$Service = ""
)

# Configuration
$ProjectName = "acquisitions"
$DevComposeFile = "docker-compose.dev.yml"
$EnvFile = ".env.development"

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
        Write-WarningMessage "Environment file $EnvFile not found"
        
        if (Test-Path ".env.example") {
            Write-InfoMessage "Creating $EnvFile from .env.example"
            Copy-Item ".env.example" $EnvFile
            Write-WarningMessage "Please edit $EnvFile with your Neon credentials before continuing"
            Write-InfoMessage "You need to set: NEON_API_KEY, NEON_PROJECT_ID, PARENT_BRANCH_ID"
            exit 1
        }
        else {
            Write-ErrorMessage "No .env.example file found to create $EnvFile"
            exit 1
        }
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
    $requiredVars = @("NEON_API_KEY", "NEON_PROJECT_ID", "PARENT_BRANCH_ID")
    $defaultValues = @("your_neon_api_key_here", "your_neon_project_id_here", "your_parent_branch_id_here")
    
    foreach ($var in $requiredVars) {
        if (-not $envVars.ContainsKey($var) -or [string]::IsNullOrWhiteSpace($envVars[$var]) -or $envVars[$var] -in $defaultValues) {
            Write-ErrorMessage "$var is not properly set in $EnvFile"
            exit 1
        }
    }
    
    Write-SuccessMessage "Environment configuration is valid"
}

function Start-DevEnvironment {
    Write-InfoMessage "🚀 Starting Acquisition App in Development Mode"
    Write-Host "================================================" -ForegroundColor Cyan
    
    # Create .neon_local directory if it doesn't exist
    if (-not (Test-Path ".neon_local")) {
        New-Item -ItemType Directory -Path ".neon_local" -Force | Out-Null
        Write-SuccessMessage "Created .neon_local directory"
    }
    
    # Add .neon_local to .gitignore if not already present
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" -Raw
        if ($gitignoreContent -notmatch "\.neon_local/") {
            Add-Content ".gitignore" "`n.neon_local/"
            Write-SuccessMessage "Added .neon_local/ to .gitignore"
        }
    }
    
    Write-InfoMessage "📦 Building and starting development containers..."
    Write-InfoMessage "   - Neon Local proxy will create an ephemeral database branch"
    Write-InfoMessage "   - Application will run with hot reload enabled"
    Write-Host ""
    
    # Build and start services
    if ($script:ComposeCmd -eq "docker compose") {
        docker compose -f $DevComposeFile up --build -d
    } else {
        docker-compose -f $DevComposeFile up --build -d
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Failed to start development environment"
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
            $psOutput = Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "ps")
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
        Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "logs")
        exit 1
    }
    
    Write-Host ""
    Write-SuccessMessage "🎉 Development environment started!"
    Write-InfoMessage "   Application: http://localhost:3000"
    Write-InfoMessage "   Database: postgres://neon:npg@localhost:5432/acquisitions"
    Write-Host ""
    Write-InfoMessage "To stop the environment, run: .\scripts\dev.ps1 stop"
}

function Stop-DevEnvironment {
    Write-InfoMessage "Stopping development environment..."
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "down")
    Write-SuccessMessage "Development environment stopped"
}

function Restart-DevEnvironment {
    Write-InfoMessage "Restarting development environment..."
    Stop-DevEnvironment
    Start-DevEnvironment
}

function Show-Logs {
    param([string]$ServiceName)
    
    if ($ServiceName) {
        Write-InfoMessage "Showing logs for $ServiceName..."
        Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "logs", "-f", $ServiceName)
    }
    else {
        Write-InfoMessage "Showing logs for all services..."
        Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "logs", "-f")
    }
}

function Show-Status {
    Write-InfoMessage "Development environment status:"
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "ps")
}

function Invoke-Migrations {
    Write-InfoMessage "📜 Running database migrations..."
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "exec", "app", "pnpm", "db:migrate")
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
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "exec", "app", "pnpm", "db:generate")
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Migrations generated successfully"
    }
    else {
        Write-ErrorMessage "Migration generation failed"
        exit 1
    }
}

function Open-DatabaseStudio {
    Write-InfoMessage "🎨 Opening Drizzle Studio..."
    Write-InfoMessage "Studio will be available at http://localhost:4983"
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "exec", "app", "pnpm", "db:studio")
}

function Open-ContainerShell {
    param([string]$ServiceName = "app")
    
    Write-InfoMessage "Opening shell in $ServiceName container..."
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "exec", $ServiceName, "sh")
}

function Invoke-Cleanup {
    Write-InfoMessage "🧹 Cleaning up development environment..."
    
    # Stop and remove containers, networks, volumes
    Invoke-DockerCompose -Arguments @("-f", $DevComposeFile, "down", "-v", "--remove-orphans")
    
    # Remove dangling images
    $danglingImages = docker images -f "dangling=true" -q 2>$null
    if ($danglingImages) {
        Write-InfoMessage "Removing dangling Docker images..."
        docker rmi $danglingImages 2>$null
    }
    
    # Clean up .neon_local directory
    if (Test-Path ".neon_local") {
        Remove-Item ".neon_local" -Recurse -Force
        Write-InfoMessage "Removed .neon_local directory"
    }
    
    Write-SuccessMessage "Cleanup completed"
}

function Show-Help {
    Write-Host @"
Development Environment Management Script
========================================

Usage: .\scripts\dev.ps1 [COMMAND] [SERVICE]

Commands:
  start       Start the development environment
  stop        Stop the development environment  
  restart     Restart the development environment
  status      Show status of services
  logs        Show logs (optionally for specific service)
  shell       Open shell in container (default: app)
  migrate     Run database migrations
  generate    Generate database migrations
  studio      Open Drizzle Studio
  cleanup     Stop and clean up all resources
  help        Show this help message

Examples:
  .\scripts\dev.ps1 start                    # Start development environment
  .\scripts\dev.ps1 logs app                 # Show logs for app service
  .\scripts\dev.ps1 shell neon-local         # Open shell in neon-local container
  .\scripts\dev.ps1 migrate                  # Run database migrations

Environment Setup:
  Make sure to configure your .env.development file with:
  - NEON_API_KEY: Your Neon API key
  - NEON_PROJECT_ID: Your Neon project ID
  - PARENT_BRANCH_ID: Your parent branch ID for ephemeral branches

For more information, see the README.md file.
"@ -ForegroundColor Cyan
}

# Main script logic
switch ($Command.ToLower()) {
    "start" {
        Test-Requirements
        Test-EnvironmentFile
        Start-DevEnvironment
    }
    "stop" {
        Test-Requirements
        Stop-DevEnvironment
    }
    "restart" {
        Test-Requirements
        Test-EnvironmentFile
        Restart-DevEnvironment
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
    "studio" {
        Test-Requirements
        Open-DatabaseStudio
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