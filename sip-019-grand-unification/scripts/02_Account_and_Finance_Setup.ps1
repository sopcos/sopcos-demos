# ==============================================================================
# SOPCOS DEVOPS - SCRIPT 02: ACCOUNT PROVISIONING & FINANCE
# Scenario: SIP-019-A & Human-in-the-Loop Financial Initialization
# Version: 1.2 (Enterprise Prefix & Auditor/Operator Funding)
# ==============================================================================

Clear-Host
Write-Host "🦅 --- SOPCOS CORE LEDGER: FINANCIAL INITIALIZATION ---" -ForegroundColor Cyan

$basePath = "C:\sopcos\core-ledger"
Set-Location -Path $basePath

# ------------------------------------------------------------------------------
# PHASE 1: ACCOUNT CREATION (ACORP, SYNAPSE, OPERATOR, AUDITOR)
# ------------------------------------------------------------------------------
Write-Host "`n[1/4] Provisioning Accounts..." -ForegroundColor Yellow

Write-Host "  - Creating account for 'acorp' (Expected Index: 3)..." -ForegroundColor Gray
.\core-ledger.exe createaccount --wallet acorp
if ($LASTEXITCODE -ne 0) { Write-Host "❌ acorp creation failed." -ForegroundColor Red; exit }

Write-Host "  - Creating account for 'acorp-synapse-edge-01' (Expected Index: 4)..." -ForegroundColor Gray
.\core-ledger.exe createaccount --wallet acorp-synapse-edge-01
if ($LASTEXITCODE -ne 0) { Write-Host "❌ acorp-synapse-edge-01 creation failed." -ForegroundColor Red; exit }

Write-Host "  - Creating account for 'acorp-operator-01' (Expected Index: 5)..." -ForegroundColor Gray
.\core-ledger.exe createaccount --wallet acorp-operator-01
if ($LASTEXITCODE -ne 0) { Write-Host "❌ acorp-operator-01 creation failed." -ForegroundColor Red; exit }

Write-Host "  - Creating account for 'acorp-auditor-01' (Expected Index: 6)..." -ForegroundColor Gray
.\core-ledger.exe createaccount --wallet acorp-auditor-01
if ($LASTEXITCODE -ne 0) { Write-Host "❌ acorp-auditor-01 creation failed." -ForegroundColor Red; exit }

Write-Host "✅ Accounts created successfully." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 2: ACCOUNT VERIFICATION
# ------------------------------------------------------------------------------
Write-Host "`n[2/4] Verifying account list..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

Write-Host "`n--- ACCOUNT INDICES TELESCOPE ---" -ForegroundColor DarkCyan
.\core-ledger.exe accounts acorp --password 1
.\core-ledger.exe accounts acorp-synapse-edge-01 --password 1
.\core-ledger.exe accounts acorp-operator-01 --password 1
Start-Sleep -Seconds 2
.\core-ledger.exe accounts acorp-auditor-01 --password 1

Write-Host "`nPlease verify indices: Acorp(3), Synapse(4), Operator(5), Auditor(6)." -ForegroundColor White
Write-Host "Press any key to proceed with the Funding Transfers..." -ForegroundColor White
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ------------------------------------------------------------------------------
# PHASE 3: GENESIS FUNDING (ADMIN TO ACORP)
# ------------------------------------------------------------------------------
Write-Host "`n[3/4] Executing Genesis Transfer (Admin #1 -> ACorp #3)..." -ForegroundColor Yellow

# Acorp'un dağıtım yapabilmesi için ana kasasına 1000 SOPC gönderiyoruz
.\core-ledger.exe send --wallet admin --from 1 --to 3 --amount 1000 --password 1 --yes

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Genesis Transfer failed." -ForegroundColor Red
} else {
    Write-Host "✅ Success! 1000 SOPC transferred to ACorp." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# PHASE 4: EDGE & HUMAN FUNDING (ACORP TO ACTORS)
# ------------------------------------------------------------------------------
Write-Host "`n[4/4] Executing Operational Funding (100 SOPC each)..." -ForegroundColor Yellow

# 1. Edge Node Funding
Write-Host "  -> Funding Synapse Edge (#4)..." -ForegroundColor Gray
.\core-ledger.exe send --wallet acorp --from 3 --to 4 --amount 100 --password 1 --yes

# 2. Operator Funding (Vinci OP_CONFESSION Gas)
Write-Host "  -> Funding Operator (#5)..." -ForegroundColor Gray
.\core-ledger.exe send --wallet acorp --from 3 --to 5 --amount 100 --password 1 --yes

# 3. Auditor Funding (Vinci OP_STATE_RESET Gas)
Write-Host "  -> Funding Auditor (#6)..." -ForegroundColor Gray
.\core-ledger.exe send --wallet acorp --from 3 --to 6 --amount 100 --password 1 --yes

Write-Host "`n--- FINANCIAL SETUP COMPLETE ---" -ForegroundColor Cyan
Write-Host "ACorp (700 SOPC), Synapse (100 SOPC), Operator (100 SOPC), Auditor (100 SOPC) are funded." -ForegroundColor Gray
Write-Host "Next Step: 03_Deploy_Smart_Unit.ps1" -ForegroundColor Yellow