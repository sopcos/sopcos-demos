# ==============================================================================
# AUDITOR STATE RESET TEST - "THE CLEAN SLATE" (REAL SIGNATURE EDITION)
# Scenario: Auditor (Level 5) resets a DIRTY system via Synapse Relay (Type 18).
# Flow: Prepare (Type 18) -> Sign (Local via Go) -> Broadcast -> Synapse Clears State
# ==============================================================================

Clear-Host
Write-Host "🛡️  --- AUDITOR: SYSTEM STATE RESET (CLEAN SLATE) ---" -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

$SynapseURL = "http://localhost:8081/api/v1/state/reset"

Write-Host "`n🛑 ACTION REQUIRED: Auditor Credentials" -ForegroundColor Red
$AuditorPubKey = Read-Host -Prompt "Enter Auditor Public Key (Hex)"
$AuditorPrivKey = Read-Host -Prompt "Enter Auditor Private Key (Hex)"
$AuditorAccountID = Read-Host -Prompt "Enter Auditor Account ID (e.g., 6)"

if ([string]::IsNullOrWhiteSpace($AuditorPubKey) -or [string]::IsNullOrWhiteSpace($AuditorPrivKey)) {
    Write-Host "❌ Keys cannot be empty. Aborting." -ForegroundColor Red
    exit
}

$AuditorDid = "did:sop:acorp-auditor-01:$AuditorPubKey"
$TargetDID = "did:sop:boiler-01"
Write-Host "✅ Auditor Identity Loaded. Target: $TargetDID" -ForegroundColor Gray

# ==============================================================================
# [STEP 0] ACCESS CHECK (PRE-FLIGHT)
# ==============================================================================
Write-Host "`n[STEP 0] ACCESS CHECK: Verifying Auditor Role via Synapse..." -ForegroundColor Yellow

# Synapse proxies this to Axon via HandleAccessCheck
$AccessCheckURL = "http://localhost:9000/api/v1/access/check?user_did=$AuditorDid&asset_did=$TargetDID"

try {
    $AccessResp = Invoke-RestMethod -Uri $AccessCheckURL -Method Get
    
    if ($AccessResp.success -eq $true -and $AccessResp.data.allowed -eq $true) {
        $Role = $AccessResp.data.role
        Write-Host "✅ ACCESS GRANTED | Role: $Role" -ForegroundColor Green
        
        if ($Role -lt 5) {
            Write-Host "🛑 PERMISSION DENIED: Role $Role is insufficient for OP_STATE_RESET (Required: 5)" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "🛑 ACCESS DENIED: $($AccessResp.data.reason)" -ForegroundColor Red
        exit
    }
} catch {
    Write-Host "❌ CHECK FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Ensure Synapse is running and Axon is reachable." -ForegroundColor Gray
    exit
}

# ==============================================================================
# [STEP 1] PREPARE TRANSACTION (OP_STATE_RESET)
# ==============================================================================
Write-Host "`n[STEP 1] PREPARE: Requesting Reset Template (Type 18)..." -ForegroundColor Yellow

$PreparePayload = @{
    public_key = $AuditorPubKey
    from_account = [int]$AuditorAccountID
    # to_account ve amount kaldırıldı (Gereksiz)
    type = 18 # OP_STATE_RESET
    # DÜZELTME: 'anchor_data' yerine 'state_reset_data' kullanılmalı
    state_reset_data = @{
        target_did = $TargetDID
        override_reference = "sha256:mock-override-ref"
        auditor_verdict = "JUSTIFIED"
        reason = "Compliance Audit #9921 Passed. System restored."
        audit_ref = "urn:sopcos:audit:2025-001"
    }
} | ConvertTo-Json -Depth 10

try {
    # Synapse HandleStateReset automatically detects 'type' field for Prepare phase
    $PrepareResponse = Invoke-RestMethod -Uri $SynapseURL -Method Post -Body $PreparePayload -ContentType "application/json"
    
    # Axon returns 'unsigned_tx_hex' and 'hash_to_sign'
    $UnsignedTxHex = $PrepareResponse.data.unsigned_tx_hex
    $HashToSign = $PrepareResponse.data.hash_to_sign

    Write-Host "✅ PREPARE SUCCESS" -ForegroundColor Green
    Write-Host "   📝 Unsigned Tx: $UnsignedTxHex" -ForegroundColor Gray
    Write-Host "   🔐 Hash To Sign: $HashToSign" -ForegroundColor DarkGray

    # ==============================================================================
    # [STEP 2] SIGN TRANSACTION (LOCAL ED25519)
    # ==============================================================================
    Write-Host "`n[STEP 2] SIGN: Generating real cryptographic signature locally..." -ForegroundColor Yellow
    
    $RealSignature = $(go run .\vinci_signer.go -key $AuditorPrivKey -hash $HashToSign)
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RealSignature)) {
        Write-Host "❌ SIGNING FAILED! Check vinci_signer.go logic." -ForegroundColor Red
        exit
    }

    $RealSignature = $RealSignature.Trim()
    Write-Host "✅ SIGN SUCCESS" -ForegroundColor Green
    Write-Host "   🖋️  Signature: $RealSignature" -ForegroundColor DarkGray

    # ==============================================================================
    # [STEP 3] BROADCAST & CLEAR STATE
    # ==============================================================================
Write-Host "`n[STEP 3] BROADCAST: Sending Signed Reset to Ledger..." -ForegroundColor Yellow

    # Note: We include 'target_did' at the root so Synapse knows which device to clear upon success.
    $BroadcastPayload = @{
        unsigned_tx_hex = $UnsignedTxHex
        signature = $RealSignature
        public_key = $AuditorPubKey
        target_did = $TargetDID 
    } | ConvertTo-Json

    $BroadcastResponse = Invoke-RestMethod -Uri $SynapseURL -Method Post -Body $BroadcastPayload -ContentType "application/json"
    
    if ($BroadcastResponse.success -eq $true) {
        $TxID = $BroadcastResponse.data.tx_id
        Write-Host "✅ RESET SUCCESS" -ForegroundColor Green
        Write-Host "   🚀 Transaction ID: $TxID" -ForegroundColor Cyan
        Write-Host "   ✨ Local State for $TargetDID should now be CLEAN." -ForegroundColor Green
    } else {
        Write-Host "❌ BROADCAST FAILED: $($BroadcastResponse)" -ForegroundColor Red
    }

} catch {
    if ($_.Exception.Response) {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $Detail = $Reader.ReadToEnd()
        Write-Host "❌ HTTP ERROR ($StatusCode): $Detail" -ForegroundColor Red
    } else {
        Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host "---------------------------------------------------"