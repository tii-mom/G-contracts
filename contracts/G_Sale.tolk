import "@stdlib/tvm-dicts"
import "types"

contract G_Sale {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token unified sale contract — 3 tiers with Ed25519 signature verification"
}

// ==================== Storage ====================

// Inline data in root cell:
//   owner(addr) | backendPublicKey(256) | paused(bool) | oracleAddress(addr)
//   ^ref: configs cell (jettonWallet + tierConfigs)
//   ^ref: state cell (anti-replay sets + tier1)
//   ^ref: orders dict (uint256→Order cell)

struct SaleStorage {
    owner: address
    backendPublicKey: uint256
    paused: bool
    oracleAddress: address
}

fun SaleStorage.load(): SaleStorage {
    var ds: slice = contract.getData().beginParse();
    return SaleStorage {
        owner: ds.loadAddress(),
        backendPublicKey: ds.loadUint(256),
        paused: ds.loadBool(),
        oracleAddress: ds.loadAddress(),
    };
}

fun SaleStorage.save(self) {
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    // Preserve refs: configCell, stateCell, ordersCell
    rootDs.loadAddress(); // skip owner
    rootDs.loadUint(256); // skip pubkey
    rootDs.skipBits(1);   // skip paused
    rootDs.loadAddress(); // skip oracle
    var configCell: cell = rootDs.loadRef();
    var stateCell: cell = rootDs.loadRef();
    val ordersCell: cell = rootDs.loadRef();

    contract.setData(
        beginCell()
            .storeAddress(self.owner)
            .storeUint(self.backendPublicKey, 256)
            .storeBool(self.paused)
            .storeAddress(self.oracleAddress)
            .storeRef(configCell)
            .storeRef(stateCell)
            .storeRef(ordersCell)
            .endCell(),
    );
}

// ==================== Config Sub-storage ====================

// configCell: jettonWalletAddr(address?) | ^tierConfigs dict
struct ConfigData {
    jettonWalletAddress: address?
    tierConfigsCell: cell? // dict<uint8, TierConfig>
}

fun loadConfigData(): ConfigData {
    var rootDs: slice = contract.getData().beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    var configCell: slice = rootDs.loadRef().beginParse();
    return ConfigData {
        jettonWalletAddress: configCell.loadAddressOpt(),
        tierConfigsCell: configCell.loadMaybeRef(),
    };
}

fun saveConfigData(config: ConfigData) {
    var storage: SaleStorage = SaleStorage.load();
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    rootDs.loadRef(); // skip old configCell
    var stateCell: cell = rootDs.loadRef();
    val ordersCell: cell = rootDs.loadRef();

    var newConfigCell: cell = beginCell()
        .storeAddressOpt(config.jettonWalletAddress)
        .storeMaybeRef(config.tierConfigsCell)
        .endCell();

    contract.setData(
        beginCell()
            .storeAddress(storage.owner)
            .storeUint(storage.backendPublicKey, 256)
            .storeBool(storage.paused)
            .storeAddress(storage.oracleAddress)
            .storeRef(newConfigCell)
            .storeRef(stateCell)
            .storeRef(ordersCell)
            .endCell(),
    );
}

// ==================== State Sub-storage ====================

// stateCell: ^usedInviteHashes dict | ^usedPurchaseNonces dict | ^usedClaimNonces dict | ^walletTier1 dict
struct StateData {
    usedInviteHashes: cell?
    usedPurchaseNonces: cell?
    usedClaimNonces: cell?
    walletTier1Bought: cell?
}

fun loadStateData(): StateData {
    var rootDs: slice = contract.getData().beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    rootDs.loadRef(); // skip configCell
    var stateSlice: slice = rootDs.loadRef().beginParse();
    return StateData {
        usedInviteHashes: stateSlice.loadMaybeRef(),
        usedPurchaseNonces: stateSlice.loadMaybeRef(),
        usedClaimNonces: stateSlice.loadMaybeRef(),
        walletTier1Bought: stateSlice.loadMaybeRef(),
    };
}

fun saveStateData(state: StateData) {
    var storage: SaleStorage = SaleStorage.load();
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    var configCell: cell = rootDs.loadRef();
    rootDs.loadRef(); // skip old stateCell
    val ordersCell: cell = rootDs.loadRef();

    var newStateCell: cell = beginCell()
        .storeMaybeRef(state.usedInviteHashes)
        .storeMaybeRef(state.usedPurchaseNonces)
        .storeMaybeRef(state.usedClaimNonces)
        .storeMaybeRef(state.walletTier1Bought)
        .endCell();

    contract.setData(
        beginCell()
            .storeAddress(storage.owner)
            .storeUint(storage.backendPublicKey, 256)
            .storeBool(storage.paused)
            .storeAddress(storage.oracleAddress)
            .storeRef(configCell)
            .storeRef(newStateCell)
            .storeRef(ordersCell)
            .endCell(),
    );
}

// ==================== Orders Sub-storage ====================

fun loadOrdersCell(): cell? {
    var rootDs: slice = contract.getData().beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    rootDs.loadRef(); // configCell
    rootDs.loadRef(); // stateCell
    return rootDs.loadMaybeRef();
}

fun saveOrdersCell(newOrdersCell: cell?) {
    var storage: SaleStorage = SaleStorage.load();
    val rootData: cell = contract.getData();
    var rootDs: slice = rootData.beginParse();
    rootDs.loadAddress();
    rootDs.loadUint(256);
    rootDs.skipBits(1);
    rootDs.loadAddress();
    var configCell: cell = rootDs.loadRef();
    var stateCell: cell = rootDs.loadRef();
    rootDs.loadMaybeRef(); // skip old orders

    contract.setData(
        beginCell()
            .storeAddress(storage.owner)
            .storeUint(storage.backendPublicKey, 256)
            .storeBool(storage.paused)
            .storeAddress(storage.oracleAddress)
            .storeRef(configCell)
            .storeRef(stateCell)
            .storeMaybeRef(newOrdersCell)
            .endCell(),
    );
}

// ==================== Tier Config ====================

// TierConfig cell: tonAmount(64) | gBaseUnits(128) | totalRounds(8) | roundGAmount(128) | active(bool) | inviteRequired(bool) | ^targetsCell
struct TierConfig {
    tonAmount: uint64
    gBaseUnits: uint128
    totalRounds: uint8
    roundGAmount: uint128
    active: bool
    inviteRequired: bool
    targetsCell: cell
}

fun TierConfig.fromCell(c: cell): TierConfig {
    var ds: slice = c.beginParse();
    return TierConfig {
        tonAmount: ds.loadUint(64),
        gBaseUnits: ds.loadUint(128),
        totalRounds: ds.loadUint(8),
        roundGAmount: ds.loadUint(128),
        active: ds.loadBool(),
        inviteRequired: ds.loadBool(),
        targetsCell: ds.loadRef(),
    };
}

fun TierConfig.toCell(self): cell {
    return beginCell()
        .storeUint(self.tonAmount, 64)
        .storeUint(self.gBaseUnits, 128)
        .storeUint(self.totalRounds, 8)
        .storeUint(self.roundGAmount, 128)
        .storeBool(self.active)
        .storeBool(self.inviteRequired)
        .storeRef(self.targetsCell)
        .endCell();
}

fun getTierTarget(tierConfig: TierConfig, round: uint8): uint32 {
    // Round is 0-based from storage. Target for round 0 is always 0.
    if (round == 0) {
        return 0;
    }
    // Parse targets cell to find target for given round
    var targetsDs: slice = tierConfig.targetsCell.beginParse();
    var i: uint8 = 0;
    while (i < round) {
        targetsDs.skipBits(32);
        i = i + 1;
    }
    return targetsDs.loadUint(32);
}

// ==================== Order ====================

// Order cell: owner(addr) | tierId(8) | claimedMask(32) | gBaseUnits(128)
struct Order {
    owner: address
    tierId: uint8
    claimedMask: uint32
    gBaseUnits: uint128
}

fun Order.fromCell(c: cell): Order {
    var ds: slice = c.beginParse();
    return Order {
        owner: ds.loadAddress(),
        tierId: ds.loadUint(8),
        claimedMask: ds.loadUint(32),
        gBaseUnits: ds.loadUint(128),
    };
}

fun Order.toCell(self): cell {
    return beginCell()
        .storeAddress(self.owner)
        .storeUint(self.tierId, 8)
        .storeUint(self.claimedMask, 32)
        .storeUint(self.gBaseUnits, 128)
        .endCell();
}

// ==================== Message Handlers ====================

fun onInternalMessage(in: InMessage) {
    if (in.body.isEmpty()) {
        return;
    }

    var cs: slice = in.body;
    val op: int = cs.loadUint(32);
    val queryId: int = cs.loadUint(64);

    if (op == OP_PURCHASE_WITH_INVITE) {
        handlePurchase(cs, in.senderAddress, in.valueCoins, queryId);
        return;
    }

    if (op == OP_CLAIM_WITH_AUTHORIZATION) {
        handleClaim(cs, in.senderAddress, queryId);
        return;
    }

    if (op == OP_CONFIGURE_BACKEND_KEY) {
        handleConfigureBackendKey(cs, in.senderAddress);
        return;
    }

    if (op == OP_CONFIGURE_JETTON_WALLET) {
        handleConfigureJettonWallet(cs, in.senderAddress);
        return;
    }

    if (op == OP_CONFIGURE_ORACLE) {
        handleConfigureOracle(cs, in.senderAddress);
        return;
    }

    if (op == OP_PAUSE) {
        handlePause(in.senderAddress);
        return;
    }

    if (op == OP_UNPAUSE) {
        handleUnpause(in.senderAddress);
        return;
    }

    if (op == OP_CONFIGURE_TIER) {
        handleConfigureTier(cs, in.senderAddress);
        return;
    }

    if (op == OP_WITHDRAW_TON) {
        handleWithdrawTon(cs, in.senderAddress);
        return;
    }

    throw Errors.InvalidMessage;
}

fun onBouncedMessage(_in: InMessageBounced) {}

// ==================== Purchase Handler ====================

fun handlePurchase(cs: slice, sender: address, msgValue: coins, queryId: int) {
    val storage: SaleStorage = SaleStorage.load();
    assert (!storage.paused) throw Errors.Paused;

    // Parse signature (512 bits = 64 bytes)
    val signatureSlice: slice = cs.loadBits(512);

    // Parse args from ref cell
    val argsCell: cell = cs.loadRef();
    var argsDs: slice = argsCell.beginParse();

    var tierId: uint8 = argsDs.loadUint(8);
    var tonAmount: uint64 = argsDs.loadUint(64);
    var gAmount: uint128 = argsDs.loadUint(128);
    var inviteHash: uint256 = argsDs.loadUint(256);
    var purchaseNonce: uint256 = argsDs.loadUint(256);
    var expiresAt: uint32 = argsDs.loadUint(32);
    val orderHash: uint256 = argsDs.loadUint(256);

    // Check expiry
    assert (blockchain.now() < expiresAt) throw Errors.Expired;

    // Reconstruct signature payload cell
    val restCell: cell = beginCell()
        .storeUint(expiresAt, 32)
        .storeUint(tonAmount, 64)
        .storeUint(gAmount, 128)
        .storeUint(tierId, 8)
        .storeUint(orderHash, 256)
        .endCell();

    val payloadCell: cell = beginCell()
        .storeAddress(sender)
        .storeUint(inviteHash, 256)
        .storeUint(purchaseNonce, 256)
        .storeRef(restCell)
        .endCell();

    // Verify signature
    val payloadHash: uint256 = payloadCell.hash();
    assert (
        isSignatureValid(payloadHash, signatureSlice, storage.backendPublicKey)
    ) throw Errors.InvalidSignature;

    // Check anti-replay
    var state: StateData = loadStateData();
    var (_dcv, dcf) = state.usedPurchaseNonces.uDictGetRef(256, purchaseNonce);
    assert (!dcf) throw Errors.PurchaseNonceUsed;

    // Load tier config
    val config: ConfigData = loadConfigData();
    assert (config.jettonWalletAddress != null) throw Errors.JettonWalletNotSet;

    val tierConfigs: cell? = config.tierConfigsCell;
    var (tierConfigCell, found) = tierConfigs.uDictGetRef(8, tierId);
    assert (found) throw Errors.TierInactive;
    val tierConfig: TierConfig = TierConfig.fromCell(tierConfigCell!);
    assert (tierConfig.active) throw Errors.TierInactive;
    assert (tonAmount == tierConfig.tonAmount) throw Errors.TonAmountMismatch;
    assert (gAmount == tierConfig.gBaseUnits) throw Errors.TonAmountMismatch;
    assert (msgValue >= tonAmount) throw Errors.TonAmountMismatch;

    // Tier1: no invite required, check one-time per address
    if (tierId == 1) {
        assert (!tierConfig.inviteRequired) throw Errors.TierInactive;
        var (_wc1: int8, senderHash: uint256) = sender.getWorkchainAndHash();
        var (_dv, df) = state.walletTier1Bought.uDictGetRef(256, senderHash);
        assert (!df) throw Errors.Tier1AlreadyBought;
    }
    // Tier2/3: invite required
    if (tierId == 2 || tierId == 3) {
        assert (tierConfig.inviteRequired) throw Errors.TierInactive;
        assert (inviteHash != 0) throw Errors.InviteAlreadyUsed;
        val (_dv, df) = state.usedInviteHashes.uDictGetRef(256, inviteHash);
        assert (!df) throw Errors.InviteAlreadyUsed;
    }

    // Check anti-replay and update
    var (_dv, df) = state.usedPurchaseNonces.uDictGetRef(256, purchaseNonce);
    assert (!df) throw Errors.PurchaseNonceUsed;
    val ds = beginCell().storeUint(1, 1).endCell();
    state.usedPurchaseNonces.uDictSetRef(256, purchaseNonce, ds);

    if (inviteHash != 0) {
        val ds = beginCell().storeUint(1, 1).endCell();
        state.usedInviteHashes.uDictSetRef(256, inviteHash, ds);
    }
    if (tierId == 1) {
        var (_wc: int8, senderHash: uint256) = sender.getWorkchainAndHash();
        val ds = beginCell().storeUint(1, 1).endCell();
        state.walletTier1Bought.uDictSetRef(256, senderHash, ds);
    }

    // Create order — round 0 (R-01) is always immediately released
    val releaseMask: uint32 = 1; // R-01 claimed immediately
    val order: Order = Order {
        owner: sender,
        tierId,
        claimedMask: releaseMask,
        gBaseUnits: gAmount,
    };
    val orderCell: cell = order.toCell();

    // Save order to dict
    var ordersDict: cell? = loadOrdersCell();
    if (ordersDict == null) {
        ordersDict = null;
    }
    ordersDict.uDictSetRef(256, orderHash, orderCell);
    saveOrdersCell(ordersDict);
    saveStateData(state);

    // Send immediate G tokens (R-01) to buyer via Jetton wallet
    var jettonWallet: address = config.jettonWalletAddress!;
    var roundGAmount: uint128 = tierConfig.roundGAmount;

    // Create Jetton transfer from sale contract's wallet to buyer
    // Note: In production, G_Sale holds G tokens in its own jetton wallet.
    // Here we send an internal_transfer message to the G_Wallet contract.
    // For MVP, we construct the Jetton internal_transfer body.

    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell(); // simple text comment prefix
    val jettonTransferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(roundGAmount as coins)
        .storeAddress(sender) // destination (buyer's wallet)
        .storeAddress(sender) // response destination
        .storeMaybeRef(null) // no custom payload
        .storeCoins(1) // forward_ton_amount (1 nanoton for notification)
        .storeSlice(forwardPayload.beginParse()) // forward_payload (Either Cell ^Cell - left cell)
        .endCell();

    // Send message to sale's jetton wallet to initiate transfer
    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(jettonWallet)
        .storeCoins(ton("0.05"))
        .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeRef(jettonTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

// ==================== Claim Handler ====================

fun handleClaim(cs: slice, sender: address, queryId: int) {
    val storage: SaleStorage = SaleStorage.load();
    assert (!storage.paused) throw Errors.Paused;

    // Parse signature (512 bits)
    val signatureSlice: slice = cs.loadBits(512);

    // Parse args from ref cell
    val argsCell: cell = cs.loadRef();
    var argsDs: slice = argsCell.beginParse();

    var orderHash: uint256 = argsDs.loadUint(256);
    var roundNumber: uint8 = argsDs.loadUint(8);
    var gAmount: uint128 = argsDs.loadUint(128);
    var claimNonce: uint256 = argsDs.loadUint(256);
    val expiresAt: uint32 = argsDs.loadUint(32);

    // Check expiry
    assert (blockchain.now() < expiresAt) throw Errors.Expired;

    // Reconstruct signature payload cell
    val payloadCell: cell = beginCell()
        .storeAddress(sender)
        .storeUint(orderHash, 256)
        .storeUint(roundNumber, 8)
        .storeUint(gAmount, 128)
        .storeUint(claimNonce, 256)
        .storeUint(expiresAt, 32)
        .endCell();

    // Verify signature
    val payloadHash: uint256 = payloadCell.hash();
    assert (
        isSignatureValid(payloadHash, signatureSlice, storage.backendPublicKey)
    ) throw Errors.InvalidSignature;

    // Anti-replay
    var state: StateData = loadStateData();
    var (_dv, df) = state.usedClaimNonces.uDictGetRef(256, claimNonce);
    assert (!df) throw Errors.ClaimNonceUsed;
    val ds = beginCell().storeUint(1, 1).endCell();
    state.usedClaimNonces.uDictSetRef(256, claimNonce, ds);

    // Find order
    var ordersDict: cell? = loadOrdersCell();
    assert (ordersDict != null) throw Errors.InvalidOrder;
    var (orderCell, orderFound) = ordersDict.uDictGetRef(256, orderHash);
    assert (orderFound) throw Errors.InvalidOrder;
    var order: Order = Order.fromCell(orderCell!);
    assert (order.owner == sender) throw Errors.InvalidOrder;

    // Check round already claimed
    assert (roundNumber > 0 && roundNumber <= 32) throw Errors.InvalidRound;
    val roundMask: uint32 = 1 << (roundNumber - 1);
    assert ((order.claimedMask & roundMask) == 0) throw Errors.RoundAlreadyClaimed;

    // Verify G amount matches expected round amount
    val config: ConfigData = loadConfigData();
    val tierConfigs: cell? = config.tierConfigsCell;
    var (tierConfigCell, tcFound) = tierConfigs.uDictGetRef(8, order.tierId);
    assert (tcFound) throw Errors.TierInactive;
    val tierConfig: TierConfig = TierConfig.fromCell(tierConfigCell!);
    assert (gAmount == tierConfig.roundGAmount) throw Errors.InvalidRound;

    // Price verification: backend checks off-chain.
    // On-chain, we verify that the backend signed it (already done above).
    // Additional on-chain oracle verification can be added via async messages.

    // Update order
    order.claimedMask = order.claimedMask | roundMask;
    orderCell = order.toCell();
    ordersDict.uDictSetRef(256, orderHash, orderCell);
    saveOrdersCell(ordersDict);
    saveStateData(state);

    // Send G tokens to buyer
    assert (config.jettonWalletAddress != null) throw Errors.JettonWalletNotSet;
    var jettonWallet: address = config.jettonWalletAddress!;

    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell();
    val jettonTransferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(queryId, 64)
        .storeCoins(gAmount as coins)
        .storeAddress(sender)
        .storeAddress(sender)
        .storeMaybeRef(null)
        .storeCoins(1)
        .storeSlice(forwardPayload.beginParse())
        .endCell();

    val msg: cell = beginCell()
        .storeUint(0x18, 6)
        .storeAddress(jettonWallet)
        .storeCoins(ton("0.05"))
        .storeUint(1, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeRef(jettonTransferBody)
        .endCell();

    sendRawMessage(msg, SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
}

// ==================== Admin Handlers ====================

fun handleConfigureBackendKey(cs: slice, sender: address) {
    var storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.backendPublicKey = cs.loadUint(256);
    storage.save();
}

fun handleConfigureJettonWallet(cs: slice, sender: address) {
    val storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    val newWallet: address = cs.loadAddress();
    var config: ConfigData = loadConfigData();
    config.jettonWalletAddress = newWallet;
    saveConfigData(config);
}

fun handleConfigureOracle(cs: slice, sender: address) {
    var storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.oracleAddress = cs.loadAddress();
    storage.save();
}

fun handlePause(sender: address) {
    var storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.paused = true;
    storage.save();
}

fun handleUnpause(sender: address) {
    var storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;
    storage.paused = false;
    storage.save();
}

fun handleConfigureTier(cs: slice, sender: address) {
    val storage: SaleStorage = SaleStorage.load();
    assert (sender == storage.owner) throw Errors.NotOwner;

    val tierId: uint8 = cs.loadUint(8);
    val tonAmount: uint64 = cs.loadUint(64);
    val gBaseUnits: uint128 = cs.loadUint(128);
    val totalRounds: uint8 = cs.loadUint(8);
    val roundGAmount: uint128 = cs.loadUint(128);
    val active: bool = cs.loadBool();
    val inviteRequired: bool = cs.loadBool();
    val targetsCell: cell = cs.loadRef();

    val tierConfig: TierConfig = TierConfig {
        tonAmount,
        gBaseUnits,
        totalRounds,
        roundGAmount,
        active,
        inviteRequired,
        targetsCell,
    };

    var config: ConfigData = loadConfigData();
    var tierConfigs: cell? = config.tierConfigsCell;
    if (tierConfigs == null) {
        tierConfigs = null;
    }
    val tcCell: cell = tierConfig.toCell();
    tierConfigs.uDictSetRef(8, tierId, tcCell);
    config.tierConfigsCell = tierConfigs;
    saveConfigData(config);
}

fun handleWithdrawTon(cs: slice, sender: address) {
    val storage: SaleStorage = SaleStorage.load();
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

get fun owner(): address {
    return SaleStorage.load().owner;
}

get fun backend_public_key(): uint256 {
    return SaleStorage.load().backendPublicKey;
}

get fun is_paused(): bool {
    return SaleStorage.load().paused;
}

get fun jetton_wallet(): address? {
    return loadConfigData().jettonWalletAddress;
}

get fun get_order(orderHash: uint256): (address?, uint8, uint32, uint128) {
    val ordersDict: cell? = loadOrdersCell();
    if (ordersDict == null) {
        return (null, 0, 0, 0);
    }
    var (orderCell, oFound) = ordersDict.uDictGetRef(256, orderHash);
    if (!oFound) {
        return (null, 0, 0, 0);
    }
    val order: Order = Order.fromCell(orderCell!);
    return (order.owner, order.tierId, order.claimedMask, order.gBaseUnits);
}
