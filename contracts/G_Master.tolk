import "types"

contract G_Master {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token Jetton Master (TEP-74 compliant)"
}

// ==================== Storage ====================

struct MasterData {
    totalSupply: coins
    adminAddress: address
    mintingFinalized: bool
    jettonContent: cell
    jettonWalletCode: cell
}

fun MasterData.load(): MasterData {
    var ds: slice = contract.getData().beginParse();
    return MasterData {
        totalSupply: ds.loadCoins(),
        adminAddress: ds.loadAddress(),
        mintingFinalized: ds.loadBool(),
        jettonContent: ds.loadRef(),
        jettonWalletCode: ds.loadRef(),
    };
}

fun MasterData.save(self) {
    contract.setData(
        beginCell()
            .storeCoins(self.totalSupply)
            .storeAddress(self.adminAddress)
            .storeBool(self.mintingFinalized)
            .storeRef(self.jettonContent)
            .storeRef(self.jettonWalletCode)
            .endCell(),
    );
}

// ==================== Mint ====================

fun mintJettonImpl(
    toAddress: address,
    jettonAmount: coins,
    deployFee: coins,
    internalTransferBody: cell,
) {
    var data: MasterData = MasterData.load();

    var stateInit: cell = calculateJettonWalletStateInit(
        toAddress,
        contract.getAddress(),
        data.jettonWalletCode,
    );
    var toWalletAddress: address = calculateJettonWalletAddress(stateInit);

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(toWalletAddress)
        .storeCoins(deployFee)
        .storeUint(4 + 2 + 1, 1 + 4 + 4 + 64 + 32 + 1 + 1 + 1)
        .storeRef(stateInit)
        .storeRef(internalTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_PAY_FEES_SEPARATELY);

    data.totalSupply = data.totalSupply + jettonAmount;
    data.save();
}

// ==================== Message Handler ====================

fun onInternalMessage(in: InMessage) {
    if (in.body.isEmpty()) {
        return;
    }

    var cs: slice = in.body;

    val op: int = cs.loadUint(32);
    val queryId: int = cs.loadUint(64);
    var data: MasterData = MasterData.load();

    if (op == OP_MINT) {
        assert (in.senderAddress == data.adminAddress) throw Errors.NotOwner;
        assert (!data.mintingFinalized) throw Errors.InvalidMessage;
        val toAddress: address = cs.loadAddress();
        var deployFee: coins = cs.loadCoins();
        val masterMsg: cell = cs.loadRef();

        var masterMsgCs: slice = masterMsg.beginParse();
        var _msgOp: int = masterMsgCs.loadUint(32);
        var _msgQueryId: int = masterMsgCs.loadUint(64);
        val jettonAmount: coins = masterMsgCs.loadCoins();

        assert (data.totalSupply + jettonAmount <= G_TOTAL_SUPPLY) throw Errors.InvalidMessage;

        mintJettonImpl(toAddress, jettonAmount, deployFee, masterMsg);
        return;
    }

    if (op == OP_BURN_NOTIFICATION) {
        val jettonAmount: coins = cs.loadCoins();
        val fromAddress: address = cs.loadAddress();

        val expectedWallet: address = calculateJettonWalletAddress(
            calculateJettonWalletStateInit(
                fromAddress,
                contract.getAddress(),
                data.jettonWalletCode,
            ),
        );
        assert (expectedWallet == in.senderAddress) throw Errors.InvalidSender;

        data.totalSupply = data.totalSupply - jettonAmount;

        var responseAddress: address? = cs.loadAddressOpt();
        if (responseAddress != null) {
            val excessMsg: cell = beginCell()
                .storeUint(0x10, 6)
                .storeAddressOpt(responseAddress)
                .storeCoins(0)
                .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
                .storeUint(OP_EXCESSES, 32)
                .storeUint(queryId, 64)
                .endCell();
            sendRawMessage(
                excessMsg,
                SEND_MODE_IGNORE_ERRORS | SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE,
            );
        }

        data.save();
        return;
    }

    if (op == OP_CHANGE_ADMIN) {
        assert (in.senderAddress == data.adminAddress) throw Errors.NotOwner;
        val newAdmin: address = cs.loadAddress();
        data.adminAddress = newAdmin;
        data.save();
        return;
    }

    if (op == OP_CHANGE_CONTENT) {
        assert (in.senderAddress == data.adminAddress) throw Errors.NotOwner;
        data.jettonContent = cs.loadRef();
        data.save();
        return;
    }

    if (op == OP_FINALIZE_MINT) {
        assert (in.senderAddress == data.adminAddress) throw Errors.NotOwner;
        data.mintingFinalized = true;
        data.save();
        return;
    }

    throw Errors.InvalidMessage;
}

fun onBouncedMessage(_in: InMessageBounced) {
    // Ignore bounced messages from master
}

// ==================== Getters ====================

get fun get_jetton_data(): (int, int, address, cell, cell) {
    val data: MasterData = MasterData.load();
    val mintable: int = data.mintingFinalized ? 0 : -1;
    return (
        data.totalSupply,
        mintable,
        data.adminAddress,
        data.jettonContent,
        data.jettonWalletCode,
    );
}

get fun get_wallet_address(ownerAddress: address): address {
    val data: MasterData = MasterData.load();
    return calculateJettonWalletAddress(
        calculateJettonWalletStateInit(ownerAddress, contract.getAddress(), data.jettonWalletCode),
    );
}

get fun is_minting_finalized(): bool {
    val data: MasterData = MasterData.load();
    return data.mintingFinalized;
}
