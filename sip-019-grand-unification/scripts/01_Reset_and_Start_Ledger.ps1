# ==============================================================================
# SOPCOS DEVOPS - SCRIPT 01: RESET & START MULTI-NODE LEDGER
# Scenario: SIP-019-A (Genesis Cleanse & Edge Provisioning)
# Version: 2.2 (Synapse Identity Added)
# ==============================================================================

Clear-Host
Write-Host "🦅 --- SOPCOS CORE LEDGER: MULTI-NODE GENESIS ---" -ForegroundColor Cyan

$basePath = "C:\sopcos\core-ledger"
Set-Location -Path $basePath

# ------------------------------------------------------------------------------
# PHASE 1: STORAGE & IDENTITY PURGE
# ------------------------------------------------------------------------------
Write-Host "`n[1/5] Purging existing databases..." -ForegroundColor Yellow
$dbFolders = @("badger_3000", "badger_3001", "badger_3002")

foreach ($folder in $dbFolders) {
    $fullPath = Join-Path $basePath $folder
    if (Test-Path $fullPath) {
        Write-Host "  - Cleaning: $folder" -ForegroundColor Gray
        Remove-Item -Path "$fullPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$walletFile = Join-Path $basePath "wallets.dat"
if (Test-Path $walletFile) {
    Write-Host "[2/5] Deleting legacy wallets.dat..." -ForegroundColor Yellow
    Remove-Item -Path $walletFile -Force
}

# ------------------------------------------------------------------------------
# PHASE 2: COMPILATION
# ------------------------------------------------------------------------------
Write-Host "`n[3/5] Building core-ledger binary..." -ForegroundColor Yellow
go build -o core-ledger.exe .\cmd\core-ledger\main.go

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed! Please check your Go environment." -ForegroundColor Red
    exit
}
Write-Host "✅ Binary compiled successfully." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 3: IDENTITY PROVISIONING
# ------------------------------------------------------------------------------
Write-Host "`n[4/5] Creating Ledger Identities..." -ForegroundColor Yellow

.\core-ledger.exe wallet create admin --password 1
.\core-ledger.exe wallet create validator-A --password 1
.\core-ledger.exe wallet create acorp --password 1
.\core-ledger.exe wallet create acorp-synapse-edge-01 --password 1
.\core-ledger.exe wallet create acorp-operator-01 --password 1
.\core-ledger.exe wallet create acorp-auditor-01 --password 1

Write-Host "`n🛑 ACTION REQUIRED: Identity rotation detected." -ForegroundColor Red
Write-Host "1. Update 'config.yaml' with the new Public Keys." -ForegroundColor Yellow
Write-Host "2. CRITICAL: Save the Public/Private Keys of the following users for ENV / Vinci integration:" -ForegroundColor Magenta
Write-Host "   - acorp-synapse-edge-01" -ForegroundColor Gray
Write-Host "   - acorp-operator-01" -ForegroundColor Gray
Write-Host "   - acorp-auditor-01" -ForegroundColor Gray
Write-Host "Press any key AFTER configuration is updated to ignite nodes..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ------------------------------------------------------------------------------
# PHASE 4: NETWORK ACTIVATION (GENESIS & VAL-A)
# ------------------------------------------------------------------------------
Write-Host "`n[5/5] Launching Ledger Network..." -ForegroundColor Cyan

# Node 0 (Genesis / Port 3000)
$node0Args = "startnode --genesis --validator --validator-wallet admin --unlock-password 1 --port 3000"
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='SOPCOS-LEDGER-3000-GENESIS'; `$Host.UI.RawUI.BackgroundColor='Black'; Clear-Host; .\core-ledger.exe $node0Args"

Write-Host "Stabilizing Genesis Node (3s)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3

# Node 1 (Validator-A / Port 3001)
$node1Args = "startnode --port 3001 --validator --validator-wallet validator-A --unlock-password 1"
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='SOPCOS-LEDGER-3001-VAL-A'; `$Host.UI.RawUI.BackgroundColor='Black'; Clear-Host; .\core-ledger.exe $node1Args"

Write-Host "`n--- MULTI-NODE STARTUP COMPLETE ---" -ForegroundColor Cyan
Write-Host "Status: Awaiting next sequence (02_Account_and_Finance_Setup.ps1)" -ForegroundColor Yellow