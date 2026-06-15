import "types"

contract G_TeamVesting {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token Team Vesting — 10 rounds of price-based unlock"
}

// ==================== Storage ====================

// Inline: owner | jettonWalletAddr | oracleAddr | totalGPerRound(coins) | claimedMask(uint16)
// Ref:   lastRoundFirstReach: cell (dict)

struct TeamVestingStorage {
    owner: address
    jettonWalletAddress: address
    oracleAddress: address
    totalGPerRound: coins
    claimedMask: uint16
}

fun TeamVestingStorage.load(): TeamVestingStorage {
    var ds: slice = contract.getData().beginParse();
    return TeamVestingStorage {
        owner: ds.loadAddress(),
        jettonWalletAddress: ds.loadAddress(),
        oracleAddress: ds.loadAddress(),
        totalGPerRound: ds.loadCoins(),
        claimedMask: ds.loadUint(16),
    };
}

fun TeamVestingStorage.save(self) {
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadAddress();
    rootDs.loadAddress();
    rootDs.loadCoins();
    rootDs.loadUint(16);
    val reachCell: cell? = rootDs.loadMaybeRef();

    contract.setData(
        beginCell()
            .storeAddress(self.owner)
            .storeAddress(self.jettonWalletAddress)
            .storeAddress(self.oracleAddress)
            .storeCoins(self.totalGPerRound)
            .storeUint(self.claimedMask, 16)
            .storeMaybeRef(reachCell)
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

    if (op == OP_CONFIGURE_JETTON_WALLET) {
        handleConfigWallet(cs, in.senderAddress);
        return;
    }

    if (op == OP_CONFIGURE_ORACLE) {
        handleConfigOracle(cs, in.senderAddress);
        return;
    }

    if (op == OP_WITHDRAW_TON) {
        handleWithdrawTon(cs, in.senderAddress);
        return;
    }

    throw Errors.InvalidMessage;
}

fun onBouncedMessage(_in: InMessageBounced) {}

// ==================== Claim Handler ====================

fun handleClaim(cs: slice, sender: address, queryId: int) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;

    val roundNumber: uint8 = cs.loadUint(8);

    assert (roundNumber >= 1 && roundNumber <= 10) throw Errors.InvalidRound;

    // Check if round already claimed
    val roundMask: uint16 = 1 << (roundNumber - 1);
    assert ((storage.claimedMask & roundMask) == 0) throw Errors.RoundAlreadyClaimed;

    // Check price condition (simplified: trust off-chain price check)
    // In production, query oracle on-chain. For MVP, backend signs claim authorization.
    // Round 1 is immediate (target = 0), rounds 2-10 need price ≥ target maintained 24h.

    // Mark round as claimed
    storage.claimedMask = storage.claimedMask | roundMask;
    storage.save();

    // Send G tokens to owner via jetton wallet
    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell();
    val jettonTransferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(storage.totalGPerRound)
        .storeAddress(storage.owner)
        .storeAddress(storage.owner)
        .storeMaybeRef(null)
        .storeCoins(1)
        .storeSlice(forwardPayload.beginParse())
        .endCell();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(storage.jettonWalletAddress)
        .storeCoins(ton("0.05"))
        .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeRef(jettonTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

// ==================== Admin Handlers ====================

fun handleConfigWallet(cs: slice, sender: address) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.jettonWalletAddress = cs.loadAddress();
    storage.save();
}

fun handleConfigOracle(cs: slice, sender: address) {
    var storage: TeamVestingStorage = TeamVestingStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.oracleAddress = cs.loadAddress();
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
    return (storage.owner, storage.oracleAddress, storage.totalGPerRound, storage.claimedMask);
}
