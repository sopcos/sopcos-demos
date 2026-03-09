# ==============================================================================
# SOPCOS DEVOPS - SCRIPT 03: SMART UNIT DEPLOYMENT & EDGE PROVISIONING
# Scenario: SIP-021 (Self-Verifying Edge Identity & IDAS)
# Version: 2.0 (Synapse Gateway Edition)
# ==============================================================================

Clear-Host
Write-Host "🦅 --- SOPCOS NEXUS: FULL DEPLOYMENT SEQUENCE ---" -ForegroundColor Cyan

$basePath = "C:\sopcos\core-ledger"
Set-Location -Path $basePath

# ------------------------------------------------------------------------------
# PHASE 1: WASM COMPILATION
# ------------------------------------------------------------------------------
Write-Host "`n[1/6] Compiling Smart Unit WASM (TinyGo)..." -ForegroundColor Yellow

# Building the registry contract
tinygo build -o examples/wasm/registry/registry.wasm -target=wasm -no-debug examples/wasm/registry/main.go

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ WASM Compilation failed!" -ForegroundColor Red
    exit
}
Write-Host "✅ registry.wasm compiled successfully." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 2: ON-CHAIN POLICY DEPLOYMENT
# ------------------------------------------------------------------------------
Write-Host "`n[2/6] Deploying WASM Policy via ACorp..." -ForegroundColor Yellow

# Note: Using --from 3 as the primary account for ACorp wallet
.\core-ledger.exe deploy examples/wasm/registry/registry.wasm --wallet acorp --password 1 --port 3000 --from 3 --gas-limit 10000000 --yes

Write-Host "`n✅ Deployment transaction submitted." -ForegroundColor Green
Write-Host "ACTION REQUIRED: Locate the 'Contract ID' in the Ledger logs." -ForegroundColor Yellow

$registryId = Read-Host -Prompt "Enter the DEPLOYED CONTRACT ID (Registry ID)"

if ([string]::IsNullOrWhiteSpace($registryId)) {
    Write-Host "❌ Registry ID is required. Aborting." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------------------------
# PHASE 3: ORGANIZATION & EDGE IDENTITY REGISTRATION
# ------------------------------------------------------------------------------
Write-Host "`n[3/6] Registering Organization & Edge Identities..." -ForegroundColor Yellow

Write-Host "  -> Registering Root Organization: did:sop:acorp" -ForegroundColor Gray
.\core-ledger.exe register-identity --did "did:sop:acorp" --role 1 --org-did "did:sop:acorp" --registry $registryId --wallet acorp --from 3 --password 1 --valid-days 3650 --yes

Write-Host "`n🛑 ACTION REQUIRED: Identity Public Keys" -ForegroundColor Red
Write-Host "Please enter the Public Keys noted from Script 01." -ForegroundColor Yellow

# 1. Synapse Edge Gateway (Role: 1)
$synapsePubKey = Read-Host -Prompt "Enter 'acorp-synapse-edge-01' Public Key (Hex)"
if ([string]::IsNullOrWhiteSpace($synapsePubKey)) { Write-Host "❌ Key required. Aborting." -ForegroundColor Red; exit }
$synapseDid = "did:sop:acorp-synapse-edge-01:$synapsePubKey"

Write-Host "  -> Registering Edge Gateway ($synapseDid)..." -ForegroundColor Gray
.\core-ledger.exe register-identity --did $synapseDid --role 1 --org-did "did:sop:acorp" --registry $registryId --wallet acorp --from 3 --password 1 --valid-days 300 --yes

# 2. Operator (Role: 2) - OP_CONFESSION yetkilisi
$operatorPubKey = Read-Host -Prompt "Enter 'acorp-operator-01' Public Key (Hex)"
if ([string]::IsNullOrWhiteSpace($operatorPubKey)) { Write-Host "❌ Key required. Aborting." -ForegroundColor Red; exit }
$operatorDid = "did:sop:acorp-operator-01:$operatorPubKey"

Write-Host "  -> Registering Operator ($operatorDid)..." -ForegroundColor Gray
.\core-ledger.exe register-identity --did $operatorDid --role 2 --org-did "did:sop:acorp" --registry $registryId --wallet acorp --from 3 --password 1 --valid-days 300 --yes

# 3. Auditor (Role: 5) - OP_STATE_RESET yetkilisi (SIP-018 Uyumlu)
$auditorPubKey = Read-Host -Prompt "Enter 'acorp-auditor-01' Public Key (Hex)"
if ([string]::IsNullOrWhiteSpace($auditorPubKey)) { Write-Host "❌ Key required. Aborting." -ForegroundColor Red; exit }
$auditorDid = "did:sop:acorp-auditor-01:$auditorPubKey"

Write-Host "  -> Registering Auditor ($auditorDid)..." -ForegroundColor Gray
.\core-ledger.exe register-identity --did $auditorDid --role 5 --org-did "did:sop:acorp" --registry $registryId --wallet acorp --from 3 --password 1 --valid-days 300 --yes

Write-Host "`n✅ All identities registered successfully with SIP-018 Authority Levels." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 4: API GATEWAY ACTIVATION
# ------------------------------------------------------------------------------
Write-Host "`n[4/6] Launching Core Ledger API..." -ForegroundColor Cyan

$env:SOPCOS_API_KEY = "maestro_secret_2025"
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='SOPCOS-CORE-API'; `$Host.UI.RawUI.BackgroundColor='Black'; Clear-Host;.\core-ledger.exe api"

Write-Host "✅ API Gateway started in a new window." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 5: IDAS CLASS CREATION
# ------------------------------------------------------------------------------
Write-Host "`n[5/6] Creating IDAS Asset Class (Industrial Boilers)..." -ForegroundColor Yellow

# Using account #3 as requested for IDAS operations
.\core-ledger.exe create-class --name "Industrial Boiler Series X" --symbol "BOILER" --type "IDAS" --wallet acorp --from 3 --password 1 --port 3000

Write-Host "`n✅ Class creation request sent." -ForegroundColor Green
Write-Host "ACTION REQUIRED: Locate the 'Calculated ClassID' in the logs." -ForegroundColor Yellow

$classId = Read-Host -Prompt "Enter the Calculated CLASS ID"

if ([string]::IsNullOrWhiteSpace($classId)) {
    Write-Host "❌ Class ID is required for minting. Aborting." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------------------------
# PHASE 6: IDAS ASSET MINTING (DIGITAL TWIN)
# ------------------------------------------------------------------------------
Write-Host "`n[6/6] Minting IDAS Asset (Digital Twin)..." -ForegroundColor Yellow

# Linking the physical serial number SN-2026-SIP21 to the Ledger asset
# Note: Recipient is 'acorp' (Owner), DID is 'boiler-01' (Digital Twin Identity).
.\core-ledger.exe mint-idas --class-id $classId --recipient "did:sop:acorp" --did "did:sop:boiler-01" --vault-ref "serial:SN-2026-SIP21" --wallet acorp --from 3 --password 1 --port 3000

Write-Host "`n✅ IDAS Minting Successful!" -ForegroundColor Green
Write-Host "Please take note of the generated ASSET ID for your records." -ForegroundColor Gray

Write-Host "`n--- FULL NEXUS DEPLOYMENT COMPLETE ---" -ForegroundColor Cyan
Write-Host "WASM Policy: Active (Registry ID: $registryId)" -ForegroundColor Gray
Write-Host "Organization: did:sop:acorp (Registered)" -ForegroundColor Gray
Write-Host "Edge Gateway: $synapseDid (Registered)" -ForegroundColor Gray
Write-Host "Asset: Boiler SN-2026-SIP21 (Minted)" -ForegroundColor Gray
Write-Host "API: Listening..." -ForegroundColor Gray
Write-Host "Next Step: Configure Synapse with its Keystore and start sending signed Verdicts!" -ForegroundColor Yellow