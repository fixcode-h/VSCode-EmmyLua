#!/usr/bin/env pwsh
# VSCode-EmmyLua Extension Package Script
# Based on .github/workflows/build.yml build process

Param(
    [string]$Target = "win32-x64",
    [string]$OutputDir = "./dist",
    [switch]$Clean = $false
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Green"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-ErrorOutput {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

# Check Node.js environment
function Test-NodeEnvironment {
    try {
        $nodeVersion = node --version
        Write-ColorOutput "[OK] Node.js version: $nodeVersion"
        return $true
    } catch {
        Write-ErrorOutput "[ERROR] Node.js not found, please install Node.js first"
        return $false
    }
}

# Clear output directory
function Clear-OutputDirectory {
    if ($Clean -and (Test-Path $OutputDir)) {
        Write-ColorOutput "[INFO] Cleaning output directory: $OutputDir"
        Remove-Item -Path $OutputDir -Recurse -Force
    }
    
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-ColorOutput "[INFO] Created output directory: $OutputDir"
    }
}

# Install dependencies
function Install-Dependencies {
    Write-ColorOutput "[STEP] Installing project dependencies..."
    try {
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed"
        }
        Write-ColorOutput "[OK] Dependencies installed successfully"
    } catch {
        Write-ErrorOutput "[ERROR] Dependencies installation failed: $_"
        exit 1
    }
}

# Download platform-specific dependencies
function Get-PlatformDependencies {
    Write-ColorOutput "[STEP] Downloading platform dependencies..."
    
    # Determine language server file based on target platform
    $languageServerFile = switch ($Target) {
        "win32-x64" { "emmylua_ls-win32-x64.zip" }
        "win32-arm64" { "emmylua_ls-win32-arm64.zip" }
        "linux-x64" { "emmylua_ls-linux-x64-glibc.2.17.tar.gz" }
        "linux-arm64" { "emmylua_ls-linux-aarch64-glibc.2.17.tar.gz" }
        "darwin-x64" { "emmylua_ls-darwin-x64.tar.gz" }
        "darwin-arm64" { "emmylua_ls-darwin-arm64.tar.gz" }
        default { "emmylua_ls-win32-x64.zip" }
    }
    
    try {
        node ./build/prepare.js $languageServerFile
        if ($LASTEXITCODE -ne 0) {
            throw "prepare.js execution failed"
        }
        Write-ColorOutput "[OK] Platform dependencies downloaded successfully"
    } catch {
        Write-ErrorOutput "[ERROR] Platform dependencies download failed: $_"
        exit 1
    }
}

# Build project
function Build-Project {
    Write-ColorOutput "[STEP] Compiling TypeScript project..."
    try {
        npm run compile
        if ($LASTEXITCODE -ne 0) {
            throw "Compilation failed"
        }
        Write-ColorOutput "[OK] Project compiled successfully"
    } catch {
        Write-ErrorOutput "[ERROR] Project compilation failed: $_"
        exit 1
    }
}

# Package extension
function Package-Extension {
    Write-ColorOutput "[STEP] Packaging VSCode extension..."
    
    $packageName = "VSCode-EmmyLua-$Target.vsix"
    $outputPath = Join-Path $OutputDir $packageName
    
    try {
        # Use --no-yarn to avoid Yarn dependency issues
        npx vsce package --no-yarn -o $outputPath --target $Target
        if ($LASTEXITCODE -ne 0) {
            throw "vsce package failed"
        }
        
        if (Test-Path $outputPath) {
            $fileSize = (Get-Item $outputPath).Length
            $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
            Write-ColorOutput "[OK] Extension packaged successfully: $packageName ($fileSizeMB MB)"
            Write-ColorOutput "[INFO] Output path: $outputPath"
        } else {
            throw "Package file not generated"
        }
    } catch {
        Write-ErrorOutput "[ERROR] Extension packaging failed: $_"
        exit 1
    }
}

# Show installation instructions
function Show-InstallInstructions {
    $packagePath = Join-Path $OutputDir "VSCode-EmmyLua-$Target.vsix"
    Write-Host ""
    Write-ColorOutput "[SUCCESS] Package completed! Installation methods:"
    Write-Host "   Method 1 (VSCode): Ctrl+Shift+P -> Extensions: Install from VSIX..." -ForegroundColor Cyan
    Write-Host "   Method 2 (Command): code --install-extension `"$packagePath`"" -ForegroundColor Cyan
}

# Main function
function Main {
    Write-ColorOutput "[START] Starting VSCode-EmmyLua extension packaging process"
    Write-ColorOutput "[INFO] Target platform: $Target"
    Write-ColorOutput "[INFO] Output directory: $OutputDir"
    Write-Host ""
    
    # Check environment
    if (!(Test-NodeEnvironment)) {
        exit 1
    }
    
    # Execute build steps
    Clear-OutputDirectory
    Install-Dependencies
    Get-PlatformDependencies
    Build-Project
    Package-Extension
    Show-InstallInstructions
    
    Write-Host ""
    Write-ColorOutput "[COMPLETE] All steps completed!"
}

# Error handling
trap {
    Write-ErrorOutput "[ERROR] Error occurred during build process: $_"
    exit 1
}

# Execute main function
Main