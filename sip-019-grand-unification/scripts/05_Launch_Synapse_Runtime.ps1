# ==============================================================================
# SOPCOS DEVOPS - SCRIPT 05: FULL RUNTIME ORCHESTRATION
# Scenario: SIP-019-A & SIP-021 (Zero-Trust Edge Activation)
# Version: 1.3 (CIIS Simulation & Clean State Enforcement)
# ==============================================================================

Clear-Host
Write-Host "🦅 --- SOPCOS NEXUS: RUNTIME ACTIVATION ---" -ForegroundColor Cyan

$axonExe = "C:\sopcos\sopcos-axon\sopcos-axon.exe"
$synapsePath = "C:\sopcos\sopcos-synapse"
$influxPath = "C:\sopcos\influxdb\influxd.exe"
$grafanaPath = "C:\sopcos\grafana-12.3.1\bin\grafana.exe"
$grafanaBinDir = "C:\sopcos\grafana-12.3.1\bin"

# ------------------------------------------------------------------------------
# PHASE 1: AXON GATEWAY ACTIVATION (THE BLIND RELAY)
# ------------------------------------------------------------------------------
Write-Host "`n[1/6] Launching Axon Gateway (Blind Relay Mode)..." -ForegroundColor Yellow

# Axon must be up first to route pre-signed verdicts and telemetry to L1
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='SOPCOS-AXON-SERVE'; `$Host.UI.RawUI.BackgroundColor='Black'; Clear-Host;  Set-Location C:\sopcos\sopcos-axon; .\sopcos-axon.exe serve"

Write-Host "Waiting for Axon to initialize (3s)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3

# ------------------------------------------------------------------------------
# PHASE 2: SYNAPSE BUILD & LOCAL CLEANUP
# ------------------------------------------------------------------------------
Write-Host "`n[2/6] Building Synapse and purging local state..." -ForegroundColor Yellow
Set-Location -Path $synapsePath

go build -o sopcos-synapse.exe .\cmd\synapse\main.go

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Synapse build failed! Please check your Go environment." -ForegroundColor Red
    exit
}

if (Test-Path ".\data") {
    Remove-Item -Path ".\data" -Recurse -Force
    Write-Host "✅ Local data directory purged for a clean start." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# PHASE 3: DATABASE STACK & TELEMETRY PURGE (SOFT RESET)
# ------------------------------------------------------------------------------
Write-Host "`n[3/6] Starting InfluxDB and Grafana Servers..." -ForegroundColor Yellow

# Start InfluxDB
Start-Process $influxPath -WindowStyle Minimized
Write-Host "✅ InfluxDB running (Minimized)." -ForegroundColor Gray

# Start Grafana
Start-Process -FilePath $grafanaPath -ArgumentList "server" -WorkingDirectory $grafanaBinDir -WindowStyle Minimized
Write-Host "✅ Grafana running (Minimized)." -ForegroundColor Gray

Write-Host "Stabilizing metrics stack (5s)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5

# Soft Reset for InfluxDB Telemetry
Write-Host "`n🛑 ACTION REQUIRED: InfluxDB Token" -ForegroundColor Red
$influxToken = Read-Host -Prompt "Enter InfluxDB Token for Telemetry Purge (or press Enter to skip)"

if (-not [string]::IsNullOrWhiteSpace($influxToken)) {
    Write-Host "  -> Purging old telemetry from 'telemetry' bucket..." -ForegroundColor Gray
    C:\sopcos\influxdb\influx.exe delete --bucket "telemetry" --org "sopcos_org" --start "1970-01-01T00:00:00Z" --stop $(Get-Date -Format yyyy-MM-ddTHH:mm:ssZ) --token $influxToken
    if ($LASTEXITCODE -eq 0) { Write-Host "✅ InfluxDB wiped clean." -ForegroundColor Green }
}

# ------------------------------------------------------------------------------
# PHASE 4: SYNAPSE RUNTIME ACTIVATION (ZERO-TRUST IDENTITY)
# ------------------------------------------------------------------------------
Write-Host "`n[4/6] Injecting Edge Credentials and Launching Synapse..." -ForegroundColor Cyan

Write-Host "`n🛑 ACTION REQUIRED: Synapse Cryptographic Keys" -ForegroundColor Red
Write-Host "Please enter the Public and Private keys generated for 'acorp-synapse-edge-01' (from Script 01)." -ForegroundColor Yellow

# 1. Ask for Keys dynamically
$synapsePubKey = Read-Host -Prompt "Enter Synapse Public Key (Hex)"
$synapsePrivKey = Read-Host -Prompt "Enter Synapse Private Key (Hex)"

if ([string]::IsNullOrWhiteSpace($synapsePubKey) -or [string]::IsNullOrWhiteSpace($synapsePrivKey)) {
    Write-Host "❌ Keys cannot be empty. Aborting Synapse startup." -ForegroundColor Red
    exit
}

# 2. Construct the Self-Verifying DID dynamically with the new prefix
$synapseDid = "did:sop:acorp-synapse-edge-01:$synapsePubKey"

# 3. Set variables in the current session
$env:SYNAPSE_DID = $synapseDid
$env:SYNAPSE_PRIVATE_KEY_HEX = $synapsePrivKey
$env:SYNAPSE_USER_ID = "4"

Write-Host "`n🔒 Cryptographic Identity loaded into memory." -ForegroundColor DarkGray
Write-Host "  -> Assigned DID: $synapseDid" -ForegroundColor Gray

# 4. Prepare and launch Synapse explicitly
$envSetup = "`$env:SYNAPSE_DID='$env:SYNAPSE_DID'; `$env:SYNAPSE_PRIVATE_KEY_HEX='$env:SYNAPSE_PRIVATE_KEY_HEX'; `$env:SYNAPSE_USER_ID='$env:SYNAPSE_USER_ID';"
$uiSetup  = "`$Host.UI.RawUI.WindowTitle='SOPCOS-SYNAPSE-RUNTIME'; `$Host.UI.RawUI.BackgroundColor='Black'; Clear-Host;"
$debugCmd = "Write-Host '--- INJECTED ENVIRONMENT VARIABLES ---' -ForegroundColor Yellow; Get-ChildItem Env:SYNAPSE_* | Format-Table -AutoSize;"
$runCmd   = "Set-Location $synapsePath; .\sopcos-synapse.exe"

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "$envSetup $uiSetup $debugCmd $runCmd"

Write-Host "`nWaiting for Synapse Edge Engine to bind (5s)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5

# ------------------------------------------------------------------------------
# PHASE 5: TELEMETRY SIMULATION (CIIS EXECUTION)
# ------------------------------------------------------------------------------
Write-Host "`n[5/6] Igniting Physical Twin (Telemetry Simulator)..." -ForegroundColor Yellow
Write-Host "Simulating Canonical Industrial Incident Scenario (ALLOW -> WARN -> HALT)" -ForegroundColor Gray

# Running the simulator (It will produce HALT and then exit)
go run .\cmd\simulator\main.go

# ------------------------------------------------------------------------------
# PHASE 6: L1 LEDGER VERIFICATION (THE AUDITOR'S VIEW)
# ------------------------------------------------------------------------------
Write-Host "`n[6/6] Independent Auditor Verification (L1 Ledger Truth)..." -ForegroundColor Cyan

Write-Host "`n--- FETCHING LATEST VERDICT ---" -ForegroundColor Yellow
go run .\cmd\showverdict\main.go -did did:sop:boiler-01

Write-Host "`nStabilizing (3s)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3

Write-Host "`n--- FETCHING TELEMETRY ANCHOR ---" -ForegroundColor Yellow
go run .\cmd\showanchor\main.go -did did:sop:boiler-01

Write-Host "`n--- NEXUS ECOSYSTEM IS LIVE & AUDIT COMPLETE ---" -ForegroundColor Green
Write-Host "1. Axon: Routing as Blind Relay" -ForegroundColor Gray
Write-Host "2. Synapse: Processing & Signing Operations" -ForegroundColor Gray
Write-Host "3. Influx/Grafana: Visualizing State" -ForegroundColor Gray
Write-Host "4. L1 Ledger: Evidence Anchored" -ForegroundColor Gray
Write-Host "`nMonitoring active at http://localhost:4000" -ForegroundColor Yellow