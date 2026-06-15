import "@stdlib/tvm-dicts"
import "types"

contract G_TeamVesting {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token Team Vesting — 10 rounds of backend-authorized claim"
}

// ==================== Storage ====================
// Root: owner | backendPublicKey(256) | totalGPerRound(coins) | claimedMask(16)
//  [ref1] walletAndOracle cell: jettonWalletAddr | oracleAddr
//  [ref2] usedClaimNonces dict

struct TeamVestingStorage {
    owner: address
    backendPublicKey: uint256
    totalGPerRound: coins
    claimedMask: uint16
}

fun TeamVestingStorage.load(): TeamVestingStorage {
    var ds: slice = contract.getData().beginParse();
    return TeamVestingStorage {
        owner: ds.loadAddress(),
        backendPublicKey: ds.loadUint(256),
        totalGPerRound: ds.loadCoins(),
        claimedMask: ds.loadUint(16),
    };
}

fun TeamVestingStorage.save(self) {
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.loadCoins();
    rootDs.loadUint(16);
    val walletOracleCell: cell = rootDs.loadRef();
    val noncesCell: cell? = rootDs.loadMaybeRef();

    contract.setData(
        beginCell()
            .storeAddress(self.owner)
            .storeUint(self.backendPublicKey, 256)
            .storeCoins(self.totalGPerRound)
            .storeUint(self.claimedMask, 16)
            .storeRef(walletOracleCell)
            .storeMaybeRef(noncesCell)
            .endCell(),
    );
}

// ==================== Wallet/Oracle sub-storage ====================

struct WalletOracleData {
    jettonWalletAddress: address
    oracleAddress: address
}

fun loadWalletOracle(): WalletOracleData {
    var rootDs: slice = contract.getData().beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.loadCoins();
    rootDs.loadUint(16);
    var woSlice: slice = rootDs.loadRef().beginParse();
    return WalletOracleData {
        jettonWalletAddress: woSlice.loadAddress(),
        oracleAddress: woSlice.loadAddress(),
    };
}

fun saveWalletOracle(data: WalletOracleData) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.loadCoins();
    rootDs.loadUint(16);
    rootDs.loadRef(); // skip old
    val noncesCell: cell? = rootDs.loadMaybeRef();

    val woCell: cell = beginCell()
        .storeAddress(data.jettonWalletAddress)
        .storeAddress(data.oracleAddress)
        .endCell();

    contract.setData(
        beginCell()
            .storeAddress(storage.owner)
            .storeUint(storage.backendPublicKey, 256)
            .storeCoins(storage.totalGPerRound)
            .storeUint(storage.claimedMask, 16)
            .storeRef(woCell)
            .storeMaybeRef(noncesCell)
            .endCell(),
    );
}

// ==================== Anti-replay helpers ====================

fun loadClaimNonces(): cell? {
    var rootDs: slice = contract.getData().beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.loadCoins();
    rootDs.loadUint(16);
    rootDs.loadRef(); // skip walletOracle
    return rootDs.loadMaybeRef();
}

fun saveClaimNonces(newNonces: cell?) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.loadCoins();
    rootDs.loadUint(16);
    val walletOracleCell: cell = rootDs.loadRef();
    rootDs.loadMaybeRef(); // skip old nonces

    contract.setData(
        beginCell()
            .storeAddress(storage.owner)
            .storeUint(storage.backendPublicKey, 256)
            .storeCoins(storage.totalGPerRound)
            .storeUint(storage.claimedMask, 16)
            .storeRef(walletOracleCell)
            .storeMaybeRef(newNonces)
            .endCell(),
    );
}

// ==================== Message Handler ====================

fun onInternalMessage(in: InMessage) {
    if (in.body.isEmpty()) {
        return;
    }

    var cs: slice = in.body;
    val op: int = cs.loadUint(32);
    val queryId: int = cs.loadUint(64);

    if (op == OP_CLAIM_WITH_AUTHORIZATION) {
        handleClaim(cs, in.senderAddress, queryId);
        return;
    }
    if (op == OP_CONFIGURE_BACKEND_KEY) {
        handleConfigBackendKey(cs, in.senderAddress);
        return;
    }
    if (op == OP_CONFIGURE_JETTON_WALLET) {
        handleConfigWallet(cs, in.senderAddress);
        return;
    }
    if (op == OP_CONFIGURE_ORACLE) {
        handleConfigOracle(cs, in.senderAddress);
        return;
    }
    if (op == OP_CONFIGURE_VESTING_AMOUNT) {
        handleConfigVestingAmount(cs, in.senderAddress);
        return;
    }
    if (op == OP_WITHDRAW_TON) {
        handleWithdrawTon(cs, in.senderAddress);
        return;
    }
    throw Errors.InvalidMessage;
}

fun onBouncedMessage(in: InMessageBounced) {
    in.bouncedBody.skipBouncedPrefix();
}

// ==================== Claim Handler ====================

fun handleClaim(cs: slice, sender: address, queryId: int) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();

    val signatureSlice: slice = cs.loadBits(512);
    val argsCell: cell = cs.loadRef();
    var argsDs: slice = argsCell.beginParse();

    val roundNumber: uint8 = argsDs.loadUint(8);
    val gAmount: uint128 = argsDs.loadUint(128);
    val claimNonce: uint256 = argsDs.loadUint(256);
    val expiresAt: uint32 = argsDs.loadUint(32);

    assert (blockchain.now() < expiresAt) throw Errors.Expired;

    // Reconstruct signature payload cell (domain-separated)
    val addrCell: cell = beginCell().storeAddress(contract.getAddress()).endCell();
    val payloadCell: cell = beginCell()
        .storeAddress(sender)
        .storeUint(0, 32)
        .storeUint(SCHEMA_VERSION, 32)
        .storeUint(roundNumber, 8)
        .storeUint(gAmount, 128)
        .storeUint(claimNonce, 256)
        .storeUint(expiresAt, 32)
        .storeRef(addrCell)
        .endCell();

    val payloadHash: uint256 = payloadCell.hash();
    assert (
        isSignatureValid(payloadHash, signatureSlice, storage.backendPublicKey)
    ) throw Errors.InvalidSignature;

    var nonces: cell? = loadClaimNonces();
    if (nonces != null) {
        var (_dv, nf) = nonces.uDictGetRef(256, claimNonce);
        assert (!nf) throw Errors.ClaimNonceUsed;
    }
    if (nonces == null) {
        nonces = null;
    }
    val ds = beginCell().storeUint(1, 1).endCell();
    nonces.uDictSetRef(256, claimNonce, ds);
    saveClaimNonces(nonces);

    assert (roundNumber >= 1 && roundNumber <= 10) throw Errors.InvalidRound;
    val roundMask: uint16 = 1 << (roundNumber - 1);
    assert ((storage.claimedMask & roundMask) == 0) throw Errors.RoundAlreadyClaimed;
    assert (gAmount == storage.totalGPerRound) throw Errors.InvalidRound;

    storage.claimedMask = storage.claimedMask | roundMask;
    storage.save();

    val wo: WalletOracleData = loadWalletOracle();
    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell();
    val jettonTransferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(storage.totalGPerRound as coins)
        .storeAddress(storage.owner)
        .storeAddress(storage.owner)
        .storeMaybeRef(null)
        .storeCoins(1)
        .storeSlice(forwardPayload.beginParse())
        .endCell();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(wo.jettonWalletAddress)
        .storeCoins(ton("0.05"))
        .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeRef(jettonTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_REGULAR);
}

// ==================== Admin Handlers ====================

fun handleConfigBackendKey(cs: slice, sender: address) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.backendPublicKey = cs.loadUint(256);
    storage.save();
}

fun handleConfigWallet(cs: slice, sender: address) {
    var wo: WalletOracleData = loadWalletOracle();
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    wo.jettonWalletAddress = cs.loadAddress();
    saveWalletOracle(wo);
}

fun handleConfigOracle(cs: slice, sender: address) {
    var wo: WalletOracleData = loadWalletOracle();
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    wo.oracleAddress = cs.loadAddress();
    saveWalletOracle(wo);
}

fun handleConfigVestingAmount(cs: slice, sender: address) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.totalGPerRound = cs.loadCoins();
    storage.save();
}

fun handleWithdrawTon(cs: slice, sender: address) {
    val storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    var toAddress: address = cs.loadAddress();
    var amount: coins = cs.loadCoins();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(toAddress)
        .storeCoins(amount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .endCell();
    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

// ==================== Getters ====================

get fun get_vesting_data(): (address, address, int, int) {
    val storage: TeamVestingStorage = TeamVestingStorage.load();
    val wo: WalletOracleData = loadWalletOracle();
    return (storage.owner, wo.oracleAddress, storage.totalGPerRound, storage.claimedMask);
}
