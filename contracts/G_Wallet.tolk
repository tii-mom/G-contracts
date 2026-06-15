import "types"

contract G_Wallet {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token Jetton Wallet (TEP-74 compliant)"
}

// ==================== Storage ====================

struct WalletData {
    balance: coins
    ownerAddress: address
    jettonMasterAddress: address
    jettonWalletCode: cell
}

fun WalletData.load(): WalletData {
    var ds: slice = contract.getData().beginParse();
    return WalletData {
        balance: ds.loadCoins(),
        ownerAddress: ds.loadAddress(),
        jettonMasterAddress: ds.loadAddress(),
        jettonWalletCode: ds.loadRef(),
    };
}

fun WalletData.save(self) {
    contract.setData(
        beginCell()
            .storeCoins(self.balance)
            .storeAddress(self.ownerAddress)
            .storeAddress(self.jettonMasterAddress)
            .storeRef(self.jettonWalletCode)
            .endCell(),
    );
}

// ==================== Gas / Storage Fees ====================

/// # Safety
/// Returns the minimum TON required for storage fees (0.01 TON).
/// This constant ensures the contract can pay rent. No preconditions.
@pure
fun minTonsForStorage(): coins
    asm "10000000 PUSHINT"

/// # Safety
/// Returns estimated gas consumption (0.015 TON) for wallet operations.
/// Used to validate sufficient TON is attached to messages. No preconditions.
@pure
fun gasConsumption(): coins
    asm "15000000 PUSHINT"

// ==================== Transfer (outgoing) ====================

fun sendTokens(body: slice, senderAddress: address, msgValue: coins, fwdFee: coins) {
    var queryId: int = body.loadUint(64);
    var jettonAmount: coins = body.loadCoins();
    val toOwnerAddress: address = body.loadAddress();
    assertBasechain(toOwnerAddress);

    var data: WalletData = WalletData.load();
    data.balance = data.balance - jettonAmount;

    assert (data.ownerAddress == senderAddress) throw Errors.InsufficientBalance;
    assert (data.balance >= 0) throw Errors.InsufficientBalance;

    var stateInit: cell = calculateJettonWalletStateInit(
        toOwnerAddress,
        data.jettonMasterAddress,
        data.jettonWalletCode,
    );
    var toWalletAddress: address = calculateJettonWalletAddress(stateInit);
    var responseAddress: address? = body.loadAddressOpt();
    body.skipMaybeRef();                    // custom_payload (Maybe ^Cell)
    var forwardTonAmount: coins = body.loadCoins();
    assert (body.remainingBitsCount() >= 1) throw Errors.InvalidMessage;
    val eitherForwardPayload: slice = body; // remainder is forward_payload (Either Cell ^Cell)

    val fwdCount: int = (forwardTonAmount != 0) ? 2 : 1;
    assert (
        msgValue >
        forwardTonAmount + fwdCount * fwdFee + (2 * gasConsumption() + minTonsForStorage())
    ) throw Errors.InsufficientBalance;

    val internalTransferBody: cell = beginCell()
        .storeUint(OP_INTERNAL_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(jettonAmount)
        .storeAddress(data.ownerAddress)
        .storeAddressOpt(responseAddress)
        .storeCoins(forwardTonAmount)
        .storeSlice(eitherForwardPayload)
        .endCell();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(toWalletAddress)
        .storeCoins(0)
        .storeUint(4 + 2 + 1, 1 + 4 + 4 + 64 + 32 + 1 + 1 + 1)
        .storeRef(stateInit)
        .storeRef(internalTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
    data.save();
}

// ==================== Internal Transfer (incoming) ====================

fun receiveTokens(
    body: slice,
    senderAddress: address,
    myTonBalance: coins,
    fwdFee: coins,
    msgValue: coins,
) {
    var data: WalletData = WalletData.load();
    var queryId: int = body.loadUint(64);
    var jettonAmount: coins = body.loadCoins();

    data.balance = data.balance + jettonAmount;
    var fromAddress: address = body.loadAddress();
    var responseAddress: address? = body.loadAddressOpt();

    assert (
        (data.jettonMasterAddress == senderAddress) |
        (calculateJettonWalletAddress(
            calculateJettonWalletStateInit(
                fromAddress,
                data.jettonMasterAddress,
                data.jettonWalletCode,
            ),
        ) ==
        senderAddress)
    ) throw Errors.InvalidSender;

    var forwardTonAmount: coins = body.loadCoins();
    val tonBalanceBeforeMsg: coins = myTonBalance - msgValue;
    val storageFee: coins = minTonsForStorage() - min(tonBalanceBeforeMsg, minTonsForStorage());
    var remainingValue: coins = msgValue - (storageFee + gasConsumption());

    if (forwardTonAmount != 0) {
        remainingValue = remainingValue - (forwardTonAmount + fwdFee);
        val eitherForwardPayload: slice = body;

        val notificationBody: cell = beginCell()
            .storeUint(OP_TRANSFER_NOTIFICATION, 32)
            .storeUint(queryId, 64)
            .storeCoins(jettonAmount)
            .storeAddress(fromAddress)
            .storeSlice(eitherForwardPayload)
            .endCell();

        val msg: cell = beginCell()
            .storeUint(0x10, 6)
            .storeAddress(data.ownerAddress)
            .storeCoins(forwardTonAmount)
            .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
            .storeRef(notificationBody)
            .endCell();

        sendRawMessage(msg, SEND_MODE_PAY_FEES_SEPARATELY);
    }

    if (responseAddress != null && remainingValue > 0) {
        val excessMsg: cell = beginCell()
            .storeUint(0x10, 6)
            .storeAddressOpt(responseAddress)
            .storeCoins(remainingValue)
            .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
            .storeUint(OP_EXCESSES, 32)
            .storeUint(queryId, 64)
            .endCell();

        sendRawMessage(excessMsg, SEND_MODE_IGNORE_ERRORS);
    }

    data.save();
}

// ==================== Burn ====================

fun burnTokens(body: slice, senderAddress: address, msgValue: coins, fwdFee: coins) {
    var data: WalletData = WalletData.load();
    var queryId: int = body.loadUint(64);
    var jettonAmount: coins = body.loadCoins();
    val responseAddress: address? = body.loadAddressOpt();
    // skip custom_payload
    var _custom: cell? = body.loadMaybeRef();

    data.balance = data.balance - jettonAmount;
    assert (data.ownerAddress == senderAddress) throw Errors.InsufficientBalance;
    assert (data.balance >= 0) throw Errors.InsufficientBalance;
    assert (msgValue > fwdFee + 2 * gasConsumption()) throw Errors.InsufficientBalance;

    val burnNotifyBody: cell = beginCell()
        .storeUint(OP_BURN_NOTIFICATION, 32)
        .storeUint(queryId, 64)
        .storeCoins(jettonAmount)
        .storeAddress(data.ownerAddress)
        .storeAddressOpt(responseAddress)
        .endCell();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(data.jettonMasterAddress)
        .storeCoins(0)
        .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeRef(burnNotifyBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
    data.save();
}

// ==================== Message Handlers ====================

fun onInternalMessage(in: InMessage) {
    if (in.body.isEmpty()) {
        return;
    }

    var cs: slice = in.body;
    val op: int = cs.loadUint(32);

    if (op == OP_TRANSFER) {
        sendTokens(cs, in.senderAddress, in.valueCoins, in.originalForwardFee);
        return;
    }

    if (op == OP_INTERNAL_TRANSFER) {
        receiveTokens(
            cs,
            in.senderAddress,
            contract.getOriginalBalance(),
            in.originalForwardFee,
            in.valueCoins,
        );
        return;
    }

    if (op == OP_BURN) {
        burnTokens(cs, in.senderAddress, in.valueCoins, in.originalForwardFee);
        return;
    }

    throw Errors.InvalidMessage;
}

fun onBouncedMessage(in: InMessageBounced) {
    var body: slice = in.bouncedBody;
    body.skipBouncedPrefix();
    val op: int = body.loadUint(32);
    assert (
        (op == OP_INTERNAL_TRANSFER) | (op == OP_BURN_NOTIFICATION)
    ) throw Errors.InvalidMessage;
    body.skipBits(64); // query_id
    val jettonAmount: coins = body.loadCoins();

    var data: WalletData = WalletData.load();
    data.balance = data.balance + jettonAmount;
    data.save();
}

// ==================== Getter ====================

get fun get_wallet_data(): (int, address, address, cell) {
    val data: WalletData = WalletData.load();
    return (data.balance, data.ownerAddress, data.jettonMasterAddress, data.jettonWalletCode);
}
