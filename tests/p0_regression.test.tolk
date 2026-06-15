import "@stdlib/tvm-dicts"
import "@acton/build"
import "@acton/crypto"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"

import "@contracts/types"
import "@wrappers/GMaster.gen"
import "@wrappers/GSale.gen"
import "@wrappers/GTeamVesting.gen"

// ==================== Helper: deploy G_Sale with Tier1 config ====================

fun deploySaleWithTier1(kp: KeyPair, deployer: Treasury): GSale {
    val t1Targets: cell = beginCell().storeUint(0, 32).endCell();
    var tierConfigs: cell? = null;
    val tcCell: cell = beginCell()
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(50000000000, 128)
        .storeBool(true)
        .storeBool(false)
        .storeUint(50000, 32)
        .storeUint(0, 32)
        .storeRef(t1Targets)
        .endCell();
    tierConfigs.uDictSetRef(8, 1, tcCell);

    val configCell: cell = beginCell()
        .storeAddressOpt(deployer.address)
        .storeMaybeRef(tierConfigs)
        .endCell();
    val stateCell: cell = beginCell()
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .endCell();
    val saleStorage: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(kp.publicKey, 256)
        .storeBool(false)
        .storeAddress(deployer.address)
        .storeRef(configCell)
        .storeRef(stateCell)
        .storeMaybeRef(null)
        .endCell();

    val stateInit = ContractState {
        code: build("G_Sale"),
        data: saleStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GSale {
        address: addr,
        stateInit,
    };
    contract.deploy(deployer.address, { value: ton("5") });
    return contract;
}

// ==================== P0-1: Admin config after empty orders ====================

get fun `test admin config works with empty orders`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();
    val contract = deploySaleWithTier1(kp, deployer);

    // configureBackendKey should work with empty orders (previously a blocker)
    val newKeyBody: cell = beginCell()
        .storeUint(OP_CONFIGURE_BACKEND_KEY, 32)
        .storeUint(0, 64)
        .storeUint(kp.publicKey, 256)
        .endCell();
    val res = contract.sendAny(deployer.address, newKeyBody, { value: ton("1") });
    expect(res).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });

    // pause/unpause should also work
    val pauseBody: cell = beginCell().storeUint(OP_PAUSE, 32).storeUint(0, 64).endCell();
    val res2 = contract.sendAny(deployer.address, pauseBody, { value: ton("1") });
    expect(res2).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });
}

// ==================== Duplicate purchaseNonce rejected ====================

get fun `test duplicate purchaseNonce is rejected`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();
    val contract = deploySaleWithTier1(kp, deployer);

    // First purchase
    val restCell: cell = beginCell()
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(100, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(1, 256)
        .storeRef(restCell)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(1, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(100, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    val res1 = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res1).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });

    // Second purchase with SAME nonce — should fail
    val res2 = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res2).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.PurchaseNonceUsed,
    });
}

// ==================== Expired signature rejected ====================

get fun `test expired signature is rejected`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();
    val contract = deploySaleWithTier1(kp, deployer);

    val restCell: cell = beginCell()
        .storeUint(100, 32) // expiresAt in the past
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(200, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(2, 256)
        .storeRef(restCell)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(2, 256)
        .storeUint(100, 32)
        .storeUint(200, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    val res = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.Expired,
    });
}

// ==================== Tier cap reached rejected ====================

get fun `test tier cap reached is rejected`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();

    // Deploy with maxPurchases=1, purchaseCount=1 (already full)
    val t1Targets: cell = beginCell().storeUint(0, 32).endCell();
    var tierConfigs: cell? = null;
    val tcCell: cell = beginCell()
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(50000000000, 128)
        .storeBool(true)
        .storeBool(false)
        .storeUint(1, 32)
        .storeUint(1, 32) // max=1, count=1 (FULL)
        .storeRef(t1Targets)
        .endCell();
    tierConfigs.uDictSetRef(8, 1, tcCell);

    val configCell: cell = beginCell()
        .storeAddressOpt(deployer.address)
        .storeMaybeRef(tierConfigs)
        .endCell();
    val stateCell: cell = beginCell()
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .endCell();
    val saleStorage: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(kp.publicKey, 256)
        .storeBool(false)
        .storeAddress(deployer.address)
        .storeRef(configCell)
        .storeRef(stateCell)
        .storeMaybeRef(null)
        .endCell();

    val stateInit = ContractState {
        code: build("G_Sale"),
        data: saleStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GSale {
        address: addr,
        stateInit,
    };
    contract.deploy(deployer.address, { value: ton("5") });

    val restCell: cell = beginCell()
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(300, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(3, 256)
        .storeRef(restCell)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(3, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(300, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    val res = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.TierCapReached,
    });
}

// ==================== Pause blocks purchase, unpause restores ====================

get fun `test pause and unpause`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();
    val contract = deploySaleWithTier1(kp, deployer);

    // Pause
    val pauseBody: cell = beginCell().storeUint(OP_PAUSE, 32).storeUint(0, 64).endCell();
    val res0 = contract.sendAny(deployer.address, pauseBody, { value: ton("1") });
    expect(res0).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });

    // Purchase should fail
    val restCell: cell = beginCell()
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(400, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(4, 256)
        .storeRef(restCell)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(4, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(400, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    val res1 = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res1).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.Paused,
    });

    // Unpause
    val unpauseBody: cell = beginCell().storeUint(OP_UNPAUSE, 32).storeUint(0, 64).endCell();
    contract.sendAny(deployer.address, unpauseBody, { value: ton("1") });

    // Purchase should succeed now
    val payloadCell2: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(5, 256)
        .storeRef(restCell)
        .endCell();
    val sig2: slice = crypto.sign(kp.privateKey, payloadCell2);

    val argsCell2: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(5, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(400, 256)
        .endCell();
    val msgBody2: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig2)
        .storeRef(argsCell2)
        .endCell();

    val res2 = contract.sendAny(deployer.address, msgBody2, { value: ton("10") });
    expect(res2).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });
}

// ==================== G_Master supply cap check ====================

get fun `test G_Master mint exceeds supply cap fails`() {
    val deployer = testing.treasury("deployer");
    val content = createEmptyCell();
    val walletCode = build("G_Wallet");

    // Deploy with totalSupply already at G_TOTAL_SUPPLY
    val masterStorage = beginCell()
        .storeCoins(G_TOTAL_SUPPLY)
        .storeAddress(deployer.address)
        .storeBool(false)
        .storeRef(content)
        .storeRef(walletCode)
        .endCell();

    val stateInit = ContractState {
        code: build("G_Master"),
        data: masterStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GMaster {
        address: addr,
        stateInit,
    };
    contract.deploy(deployer.address, { value: ton("1") });

    // Try to mint more — should fail
    val internalTransferBody: cell = beginCell()
        .storeUint(OP_INTERNAL_TRANSFER, 32)
        .storeUint(0, 64)
        .storeCoins(1)
        .storeAddress(deployer.address)
        .storeAddressOpt(null)
        .storeCoins(0)
        .storeSlice(beginCell().storeUint(0, 32).endCell().beginParse())
        .endCell();
    val mintBody: cell = beginCell()
        .storeUint(OP_MINT, 32)
        .storeUint(0, 64)
        .storeAddress(deployer.address)
        .storeCoins(0)
        .storeRef(internalTransferBody)
        .endCell();

    // Mint from admin
    val res = contract.sendAny(deployer.address, mintBody, { value: ton("5") });
    // Should fail — supply exceeded
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.InvalidMessage,
    });
}

// ==================== G_Master finalize blocks further mint ====================

get fun `test G_Master finalize blocks mint`() {
    val deployer = testing.treasury("deployer");
    val content = createEmptyCell();
    val walletCode = build("G_Wallet");

    val masterStorage = beginCell()
        .storeCoins(0)
        .storeAddress(deployer.address)
        .storeBool(false)
        .storeRef(content)
        .storeRef(walletCode)
        .endCell();
    val stateInit = ContractState {
        code: build("G_Master"),
        data: masterStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GMaster {
        address: addr,
        stateInit,
    };
    contract.deploy(deployer.address, { value: ton("1") });

    // Finalize mint
    val finalizeBody: cell = beginCell().storeUint(OP_FINALIZE_MINT, 32).storeUint(0, 64).endCell();
    val res0 = contract.sendAny(deployer.address, finalizeBody, { value: ton("1") });
    expect(res0).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });

    // Mint should fail after finalize
    val internalTransferBody: cell = beginCell()
        .storeUint(OP_INTERNAL_TRANSFER, 32)
        .storeUint(0, 64)
        .storeCoins(1000)
        .storeAddress(deployer.address)
        .storeAddressOpt(null)
        .storeCoins(0)
        .storeSlice(beginCell().storeUint(0, 32).endCell().beginParse())
        .endCell();
    val mintBody: cell = beginCell()
        .storeUint(OP_MINT, 32)
        .storeUint(0, 64)
        .storeAddress(deployer.address)
        .storeCoins(0)
        .storeRef(internalTransferBody)
        .endCell();

    val res = contract.sendAny(deployer.address, mintBody, { value: ton("5") });
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.InvalidMessage,
    });
}

// ==================== TeamVesting claim with valid signature ====================

get fun `test TeamVesting claim with valid signature`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();

    val woCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeAddress(deployer.address)
        .endCell();

    val teamStorage = beginCell()
        .storeAddress(deployer.address)
        .storeUint(kp.publicKey, 256)
        .storeCoins(T_TEAM_PER_ROUND)
        .storeUint(0, 16)
        .storeRef(woCell)
        .storeMaybeRef(null)
        .endCell();
    val stateInit = ContractState {
        code: build("G_TeamVesting"),
        data: teamStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GTeamVesting {
        address: addr,
        stateInit,
    };
    contract.deploy(deployer.address, { value: ton("5") });

    // Build claim payload (round 1, immediate)
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(1, 8)
        .storeUint(T_TEAM_PER_ROUND, 128)
        .storeUint(1, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(T_TEAM_PER_ROUND, 128)
        .storeUint(1, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_CLAIM_WITH_AUTHORIZATION, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    val res = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });
}
