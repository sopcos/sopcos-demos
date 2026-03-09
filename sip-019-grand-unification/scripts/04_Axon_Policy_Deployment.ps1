# ==============================================================================
# SOPCOS DEVOPS - SCRIPT 04: AXON POLICY BUILD, PUBLISHING & ENFORCEMENT
# Scenario: SIP-019-A (Nexus Intelligence Layer)
# Version: 1.2 (Clean Slate DB Purge Added)
# ==============================================================================

Clear-Host
Write-Host "🦅 --- SOPCOS AXON: POLICY ORCHESTRATION & ENFORCEMENT ---" -ForegroundColor Cyan

$axonPath = "C:\sopcos\sopcos-axon"
Set-Location -Path $axonPath

# ------------------------------------------------------------------------------
# PHASE 0: PURGE LOCAL STATE (CLEAN SLATE)
# ------------------------------------------------------------------------------
Write-Host "`n[0/6] Purging old Axon local database..." -ForegroundColor Yellow
$axonDataPath = Join-Path $axonPath "data"

if (Test-Path $axonDataPath) {
    Remove-Item -Path $axonDataPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - Axon local state wiped (Badger DB cleared)." -ForegroundColor Gray
} else {
    Write-Host "  - No existing data folder found. Proceeding cleanly." -ForegroundColor Gray
}

# ------------------------------------------------------------------------------
# PHASE 1: COMPILATION (AXON & POLICY)
# ------------------------------------------------------------------------------
Write-Host "`n[1/6] Building Axon binary and WASM policy..." -ForegroundColor Yellow

go build -o sopcos-axon.exe .\cmd\axon\main.go
go run tools/builder.go

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Compilation failed." -ForegroundColor Red
    exit
}
Write-Host "✅ Binary and WASM policy built successfully." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 2: ENVIRONMENT CONFIGURATION
# ------------------------------------------------------------------------------
Write-Host "`n[2/6] Configuring Cloud Environment..." -ForegroundColor Yellow
$env:AWS_ACCESS_KEY_ID = Read-Host -Prompt "Enter AWS_ACCESS_KEY_ID"
$secureSecret = Read-Host -AsSecureString -Prompt "Enter AWS_SECRET_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new("", $secureSecret).Password
$env:AWS_REGION = Read-Host -Prompt "Enter AWS_REGION"

# ------------------------------------------------------------------------------
# PHASE 3: CLOUD PUBLISHING
# ------------------------------------------------------------------------------
Write-Host "`n[3/6] Publishing WASM to Cloud Vault (S3)..." -ForegroundColor Yellow

go run tools/publisher.go --did "did:sop:boiler-01" --bucket "sopcos-vault" --type "unit_master" --capabilities "pressure,vibration,temperature,rpm"

Write-Host "`n✅ Cloud upload complete." -ForegroundColor Green
Write-Host "ACTION REQUIRED: Copy the publisher output to '.\artifacts\payload.json' and save." -ForegroundColor Yellow
Read-Host -Prompt "Press Enter AFTER saving artifacts/payload.json (Also please don't forget to update acorp private key to config.yaml)"

# ------------------------------------------------------------------------------
# PHASE 4: LEDGER TRANSACTION (ANCHORING)
# ------------------------------------------------------------------------------
Write-Host "`n[4/6] Submitting transaction to Core Ledger..." -ForegroundColor Yellow
$env:SOPCOS_API_KEY = "maestro_secret_2025"

go run tools/submit_transaction.go --payload .\artifacts\payload.json --config config.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Ledger transaction failed." -ForegroundColor Red
    exit
}
Write-Host "✅ Policy anchored to Ledger successfully." -ForegroundColor Green

# ------------------------------------------------------------------------------
# PHASE 5: VERIFICATION (CURL & JSON PARSING)
# ------------------------------------------------------------------------------
Write-Host "`n[5/6] Verifying Deployment via API Gateway..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
$env:SOPCOS_API_KEY = "maestro_secret_2025"
$responseRaw = curl.exe -s -H "X-Sopcos-Key: $env:SOPCOS_API_KEY" http://localhost:8080/artifact/did:sop:boiler-01

# Convert raw JSON string to a PowerShell Object
$response = $responseRaw | ConvertFrom-Json

# Check if success is true and if the DID matches in the data block
if ($response.success -eq $true -and $response.data.author_did -eq "did:sop:boiler-01") {
    Write-Host "✅ Verification Success: Policy found on Ledger!" -ForegroundColor Green
    Write-Host "URN: $($response.data.urn)" -ForegroundColor Gray
} else {
    Write-Host "⚠️ Warning: Policy record not found or API returned error." -ForegroundColor Red
    Write-Host "Response: $responseRaw" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# PHASE 6: LOCAL ENFORCEMENT TEST (TRUTH CHECK)
# ------------------------------------------------------------------------------
Write-Host "`n[6/6] Running Enforcer (Policy Truth Verification)..." -ForegroundColor Yellow

$wasmUri = Read-Host -Prompt "Enter the WASM S3 URI"
$wasmHash = Read-Host -Prompt "Enter the WASM Hash"

Write-Host "Testing policy with Telemetry: Pressure=97, Vibration=0.026, Temp=250" -ForegroundColor Gray

# Running the enforcer to simulate a real Synapse verdict
go run tools/enforcer.go --uri "$wasmUri" --hash "$wasmHash" --set pressure=97 --set vibration=0.026 --set temperature=250

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Enforcer Confirmed: WASM logic is operational." -ForegroundColor Green
} else {
    Write-Host "`n❌ Enforcer Failed: WASM logic mismatch." -ForegroundColor Red
}

Write-Host "`n--- AXON DEPLOYMENT & ENFORCEMENT COMPLETE ---" -ForegroundColor Cyan
Write-Host "Next Step: 05_Launch_Synapse_Runtime.ps1" -ForegroundColor Yellow