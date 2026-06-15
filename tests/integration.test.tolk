import "@stdlib/tvm-dicts"
import "@acton/build"
import "@acton/crypto"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"

import "@contracts/types"
import "@wrappers/GSale.gen"

// ==================== Ed25519 Purchase Flow Test ====================

get fun `test Ed25519 signature verification on purchase`() {
    val deployer = testing.treasury("deployer");

    // 1. Generate keypair
    val kp = crypto.generateKeyPair();
    val pubKey: uint256 = kp.publicKey;

    // 2. Build tier targets cell for Tier 1
    val targetsCell: cell = beginCell().storeUint(0, 32).endCell();

    // 3. Build G_Sale storage with the backend public key
    val oracleAddr: address = deployer.address; // use deployer as oracle placeholder

    // Tier configs cell: dict<uint8 -> TierConfig cell>
    var tierConfigs: cell? = null;
    var tcCell: cell = beginCell()
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(50000000000, 128)
        .storeBool(true)
        .storeBool(false)
        .storeRef(targetsCell)
        .endCell();
    tierConfigs.uDictSetRef(8, 1, tcCell);

    // Build inner config cell
    val configCell: cell = beginCell()
        .storeAddressOpt(deployer.address)
        .storeMaybeRef(tierConfigs)
        .endCell();

    // Build state cell
    val stateCell: cell = beginCell()
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .storeMaybeRef(null)
        .endCell();

    // Root storage
    val saleStorage: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(pubKey, 256)
        .storeBool(false)
        .storeAddress(oracleAddr)
        .storeRef(configCell)
        .storeRef(stateCell)
        .storeMaybeRef(null)
        .endCell();

    // 4. Deploy G_Sale with custom storage
    val stateInit = ContractState {
        code: build("G_Sale"),
        data: saleStorage,
    };
    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    val contract = GSale {
        address: addr,
        stateInit,
    };
    val deployRes = contract.deploy(deployer.address, { value: ton("5") });
    expect(deployRes).toHaveSuccessfulDeploy({ to: contract.address });

    // 5. Build purchase payload cell (matching contract-payloads.ts format)
    val tierId: uint8 = 1;
    val tonAmount: uint64 = 9990000000;
    val gAmount: uint128 = 50000000000;
    val inviteHash: uint256 = 0;
    val purchaseNonce: uint256 = 1;
    val expiresAt: uint32 = blockchain.now() + 3600;
    val orderHash: uint256 = 12345;

    val restCell: cell = beginCell()
        .storeUint(expiresAt, 32)
        .storeUint(tonAmount, 64)
        .storeUint(gAmount, 128)
        .storeUint(tierId, 8)
        .storeUint(orderHash, 256)
        .endCell();

    val senderAddr: address = deployer.address;

    val payloadCell: cell = beginCell()
        .storeAddress(senderAddr)
        .storeUint(inviteHash, 256)
        .storeUint(purchaseNonce, 256)
        .storeRef(restCell)
        .endCell();

    // 6. Sign the payload cell
    val signature: slice = crypto.sign(kp.privateKey, payloadCell);

    // 7. Build IPUR message body cell
    val argsCell: cell = beginCell()
        .storeUint(tierId, 8)
        .storeUint(tonAmount, 64)
        .storeUint(gAmount, 128)
        .storeUint(inviteHash, 256)
        .storeUint(purchaseNonce, 256)
        .storeUint(expiresAt, 32)
        .storeUint(orderHash, 256)
        .endCell();

    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(signature)
        .storeRef(argsCell)
        .endCell();

    // 8. Send purchase message
    val purchaseRes = contract.sendAny(deployer.address, msgBody, { value: ton("10") });

    // 9. Verify transaction succeeded (signature validated, order created)
    expect(purchaseRes).toHaveSuccessfulTx({ from: deployer.address, to: contract.address });
}

// ==================== Negative: Tier2 inviteHash=0 rejected ====================

get fun `test Tier2 inviteHash=0 is rejected`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();

    // Deploy G_Sale with T2 config
    val t2Targets: cell = beginCell()
        .storeUint(0, 32)
        .storeUint(200, 32)
        .storeUint(500, 32)
        .storeUint(1250, 32)
        .storeUint(3125, 32)
        .endCell();
    var tierConfigs: cell? = null;
    val tcCell: cell = beginCell()
        .storeUint(99990000000, 64)
        .storeUint(1200000000000, 128)
        .storeUint(5, 8)
        .storeUint(240000000000, 128)
        .storeBool(true)
        .storeBool(true)
        .storeRef(t2Targets)
        .endCell();
    tierConfigs.uDictSetRef(8, 2, tcCell);

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

    // Build Tier2 purchase with inviteHash=0
    val restCell: cell = beginCell()
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(99990000000, 64)
        .storeUint(1200000000000, 128)
        .storeUint(2, 8)
        .storeUint(99999, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(2, 256)
        .storeRef(restCell)
        .endCell();
    val sig: slice = crypto.sign(kp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(2, 8)
        .storeUint(99990000000, 64)
        .storeUint(1200000000000, 128)
        .storeUint(0, 256)
        .storeUint(2, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(99999, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(sig)
        .storeRef(argsCell)
        .endCell();

    // Should fail with inviteHash=0 for Tier2
    val res = contract.sendAny(deployer.address, msgBody, { value: ton("100") });
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.InviteAlreadyUsed,
    });
}

// ==================== Negative: invalid signature rejected ====================

get fun `test invalid signature is rejected`() {
    val deployer = testing.treasury("deployer");
    val kp = crypto.generateKeyPair();
    val wrongKp = crypto.generateKeyPair(); // different keypair

    // Deploy with kp.publicKey
    val t1Targets: cell = beginCell().storeUint(0, 32).endCell();
    var tierConfigs: cell? = null;
    val tcCell: cell = beginCell()
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(50000000000, 128)
        .storeBool(true)
        .storeBool(false)
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

    // Build payload and sign with WRONG key
    val restCell: cell = beginCell()
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(1, 8)
        .storeUint(11111, 256)
        .endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeUint(1, 256)
        .storeRef(restCell)
        .endCell();
    val wrongSig: slice = crypto.sign(wrongKp.privateKey, payloadCell);

    val argsCell: cell = beginCell()
        .storeUint(1, 8)
        .storeUint(9990000000, 64)
        .storeUint(50000000000, 128)
        .storeUint(0, 256)
        .storeUint(1, 256)
        .storeUint(blockchain.now() + 3600, 32)
        .storeUint(11111, 256)
        .endCell();
    val msgBody: cell = beginCell()
        .storeUint(OP_PURCHASE_WITH_INVITE, 32)
        .storeUint(0, 64)
        .storeSlice(wrongSig)
        .storeRef(argsCell)
        .endCell();

    val res = contract.sendAny(deployer.address, msgBody, { value: ton("10") });
    expect(res).toHaveFailedTx({
        from: deployer.address,
        to: contract.address,
        exitCode: Errors.InvalidSignature,
    });
}
