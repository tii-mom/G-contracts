import "types"

contract G_Ecosystem {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token Ecosystem Fund — admin-managed token distribution"
}

// ==================== Storage ====================

// inline: owner | jettonWalletAddr | remainingG(coins)

struct EcosystemStorage {
    owner: address
    jettonWalletAddress: address
    remainingG: coins
}

fun EcosystemStorage.load(): EcosystemStorage {
    var ds: slice = contract.getData().beginParse();
    return EcosystemStorage {
        owner: ds.loadAddress(),
        jettonWalletAddress: ds.loadAddress(),
        remainingG: ds.loadCoins(),
    };
}

fun EcosystemStorage.save(self) {
    contract.setData(
        beginCell()
            .storeAddress(self.owner)
            .storeAddress(self.jettonWalletAddress)
            .storeCoins(self.remainingG)
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

    if (op == OP_TRANSFER_ECO) {
        handleTransfer(cs, in.senderAddress, queryId);
        return;
    }

    if (op == OP_CONFIGURE_JETTON_WALLET) {
        handleConfigWallet(cs, in.senderAddress);
        return;
    }

    if (op == OP_WITHDRAW_TON) {
        handleWithdrawTon(cs, in.senderAddress);
        return;
    }

    throw Errors.InvalidMessage;
}

fun onBouncedMessage(_in: InMessageBounced) {}

// ==================== Transfer Handler ====================

fun handleTransfer(cs: slice, sender: address, queryId: int) {
    var storage: EcosystemStorage = EcosystemStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;

    var toAddress: address = cs.loadAddress();
    var amount: coins = cs.loadCoins();

    assert (amount > 0) throw Errors.InvalidMessage;
    assert (amount <= storage.remainingG) throw Errors.InsufficientBalance;

    storage.remainingG = storage.remainingG - amount;
    storage.save();

    // Send G tokens via jetton wallet
    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell();
    val jettonTransferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(amount)
        .storeAddress(toAddress)
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

    sendRawMessage(msg, SEND_MODE_REGULAR);
}

// ==================== Admin Handlers ====================

fun handleConfigWallet(cs: slice, sender: address) {
    var storage: EcosystemStorage = EcosystemStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.jettonWalletAddress = cs.loadAddress();
    storage.save();
}

fun handleWithdrawTon(cs: slice, sender: address) {
    val storage: EcosystemStorage = EcosystemStorage.load();
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

get fun get_eco_data(): (address, address, int) {
    val storage: EcosystemStorage = EcosystemStorage.load();
    return (storage.owner, storage.jettonWalletAddress, storage.remainingG);
}
