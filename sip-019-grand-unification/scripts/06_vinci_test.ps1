# ==============================================================================
# VINCI WALLET RELAY TEST - "THE CARRIER FLOW" (REAL SIGNATURE EDITION)
# Scenario: Vinci Wallet forces system to DIRTY STATE (OP_CONFESSION) via Synapse.
# Flow: Prepare (via Synapse) -> Sign (Local via Go) -> Broadcast (via Synapse)
# ==============================================================================

Clear-Host
Write-Host "📱 --- VINCI WALLET: EMERGENCY OVERRIDE (DIRTY STATE) ---" -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

$SynapseURL = "http://localhost:8081/api/v1/vinci/relay"

Write-Host "`n🛑 ACTION REQUIRED: Operator Credentials" -ForegroundColor Red
$OperatorPubKey = Read-Host -Prompt "Enter 'acorp-operator-01' Public Key (Hex)"
$OperatorPrivKey = Read-Host -Prompt "Enter 'acorp-operator-01' Private Key (Hex)"
$OperatorAccountID = Read-Host -Prompt "Enter Operator Account ID (e.g., 5)"

if ([string]::IsNullOrWhiteSpace($OperatorPubKey) -or [string]::IsNullOrWhiteSpace($OperatorPrivKey)) {
    Write-Host "❌ Keys cannot be empty. Aborting." -ForegroundColor Red
    exit
}

$OperatorDid = "did:sop:acorp-operator-01:$OperatorPubKey"
Write-Host "✅ Operator Identity Loaded: $OperatorDid" -ForegroundColor Gray

$TargetDID = "did:sop:boiler-01"

# ==============================================================================
# [STEP 0] ACCESS CHECK (PRE-FLIGHT)
# ==============================================================================
Write-Host "`n[STEP 0] ACCESS CHECK: Verifying Operator Role via Synapse..." -ForegroundColor Yellow

# Synapse proxies this to Axon via HandleAccessCheck
$AccessCheckURL = "http://localhost:9000/api/v1/access/check?user_did=$OperatorDid&asset_did=$TargetDID"

try {
    $AccessResp = Invoke-RestMethod -Uri $AccessCheckURL -Method Get
    
    if ($AccessResp.success -eq $true -and $AccessResp.data.allowed -eq $true) {
        $Role = $AccessResp.data.role
        Write-Host "✅ ACCESS GRANTED | Role: $Role" -ForegroundColor Green
        
        if ($Role -lt 2) {
            Write-Host "🛑 PERMISSION DENIED: Role $Role is insufficient for OP_CONFESSION (Required: 2+)" -ForegroundColor Red
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
# [STEP 1] PREPARE TRANSACTION (OP_CONFESSION)
# ==============================================================================
Write-Host "`n[STEP 1] PREPARE: Requesting Tx Template from Axon (via Synapse)..." -ForegroundColor Yellow

# SIP-011  OP_CONFESSION (Type 17) Payload
$PreparePayload = @{
    public_key = $OperatorPubKey
    from_account = [int]$OperatorAccountID
    # to_account ve amount Type 17 (Confession) için teknik olarak gereksizdir, API bunları yoksayar.
    type = 17
    anchor_data = @{
        target_did = $TargetDID
        verdict = "ALLOW"
        reason = "Manual Override due to sensor failure (Vinci UI)"
        input_hash = "sha256:dummy_input_hash_for_test"
        policy_hash = "sha256:dummy_policy_hash_for_test"
        override = @{
            justification_code = "CLASS_S"
            signer_did = $OperatorDid
            token = "auth-token-xyz"
            liability_hash = "sha256:proof-of-liability-document-hash"
        }
    }
} | ConvertTo-Json -Depth 10

try {
    # Synapse Relay requires X-Axon-Target header to route correctly
    $PrepareResponse = Invoke-RestMethod -Uri $SynapseURL -Method Post -Body $PreparePayload -ContentType "application/json" -Headers @{ "X-Axon-Target" = "/api/v1/relay/prepare" }
    
    # Axon returns 'unsigned_tx_hex' and 'hash_to_sign' in prepare phase
    $UnsignedTxHex = $PrepareResponse.data.unsigned_tx_hex
    $HashToSign = $PrepareResponse.data.hash_to_sign

    Write-Host "✅ PREPARE SUCCESS" -ForegroundColor Green
    Write-Host "   📝 Unsigned Tx: $UnsignedTxHex" -ForegroundColor Gray
    Write-Host "    Hash To Sign: $HashToSign" -ForegroundColor DarkGray

    # ==============================================================================
    # [STEP 2] SIGN TRANSACTION (LOCAL ED25519)
    # ==============================================================================
    Write-Host "`n[STEP 2] SIGN: Generating real cryptographic signature locally..." -ForegroundColor Yellow
    
    $RealSignature = $(go run .\vinci_signer.go -key $OperatorPrivKey -hash $HashToSign)
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RealSignature)) {
        Write-Host "❌ SIGNING FAILED! Check vinci_signer.go logic." -ForegroundColor Red
        exit
    }

    $RealSignature = $RealSignature.Trim()
    Write-Host "✅ SIGN SUCCESS" -ForegroundColor Green
    Write-Host "   🖋️  Signature: $RealSignature" -ForegroundColor DarkGray

    # ==============================================================================
    # [STEP 3] BROADCAST TRANSACTION
    # ==============================================================================
    Write-Host "`n[STEP 3] BROADCAST: Submitting signed transaction to Ledger..." -ForegroundColor Yellow

    $BroadcastPayload = @{
        unsigned_tx_hex = $UnsignedTxHex
        signature = $RealSignature
        public_key = $OperatorPubKey
        target_did = $TargetDID
    } | ConvertTo-Json -Depth 10

    $BroadcastResponse = Invoke-RestMethod -Uri $SynapseURL -Method Post -Body $BroadcastPayload -ContentType "application/json" -Headers @{ "X-Axon-Target" = "/api/v1/relay/broadcast" }
    
    if ($BroadcastResponse.success -eq $true) {
        $TxID = $BroadcastResponse.data.tx_id
        Write-Host "✅ BROADCAST SUCCESS: The System is now in DIRTY STATE!" -ForegroundColor Green
        Write-Host "   🚀 Transaction ID: $TxID" -ForegroundColor Cyan
        Write-Host "`n🔗 Verify at: http://localhost:8080/tx/$TxID" -ForegroundColor Gray
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