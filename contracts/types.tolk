enum Errors {
    NotOwner = 101
    Paused = 102
    InvalidSignature = 103
    Expired = 104
    InviteAlreadyUsed = 105
    PurchaseNonceUsed = 106
    ClaimNonceUsed = 107
    PurchaseLimitExceeded = 108
    TonAmountMismatch = 109
    InvalidOrder = 110
    RoundAlreadyClaimed = 111
    InvalidRound = 112
    JettonWalletNotSet = 113
    Tier1AlreadyBought = 114
    PriceNotMaintained = 115
    TierInactive = 116
    TierCapReached = 117
    InsufficientBalance = 706
    InvalidSender = 707
    InvalidMessage = 65535
}

// ==================== Workchain ====================

/// # Safety
/// This asm pushes a constant 0 as the basechain workchain ID.
/// It is purely a constant value with no side effects or preconditions.
@pure
fun basechainWorkchain(): int8
    asm "0 PUSHINT"

fun assertBasechain(addr: address) {
    var (wc: int8, _hash: uint256) = addr.getWorkchainAndHash();
    assert (wc == basechainWorkchain()) throw Errors.InvalidSender;
}

// ==================== Send Modes (from stdlib) ====================
// SEND_MODE_REGULAR, SEND_MODE_PAY_FEES_SEPARATELY, SEND_MODE_IGNORE_ERRORS,
// SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE are defined in @stdlib/common

// ==================== Standard Jetton Opcodes (TEP-74) ====================

const OP_TRANSFER: int = 0x0f8a7ea5
const OP_TRANSFER_NOTIFICATION: int = 0x7362d09c
const OP_INTERNAL_TRANSFER: int = 0x178d4519
const OP_EXCESSES: int = 0xd53276db
const OP_BURN: int = 0x595f07bc
const OP_BURN_NOTIFICATION: int = 0x7bdd97de

// ==================== G-Specific Contract Opcodes ====================

// G_Sale opcodes
const OP_PURCHASE_WITH_INVITE: int = 0x49505552 // "IPUR"
const OP_CLAIM_WITH_AUTHORIZATION: int = 0x49434c4d // "ICLM"
const OP_CONFIGURE_BACKEND_KEY: int = 0x41424b59 // "ABKY"
const OP_CONFIGURE_JETTON_WALLET: int = 0x414a574c // "AJWL"
const OP_CONFIGURE_ORACLE: int = 0x414f5243 // "AORC"
const OP_PAUSE: int = 0x41505553 // "APUS"
const OP_UNPAUSE: int = 0x41554e50 // "AUNP"
const OP_CONFIGURE_TIER: int = 0x41544952 // "ATIR"
const OP_WITHDRAW_TON: int = 0x57544f4e // "WTON"
const OP_WITHDRAW_G: int = 0x57474f4b // "WGOK"

// PriceOracle opcodes
const OP_UPDATE_PRICE: int = 0x55504454 // "UPDT"
const OP_GET_PRICE: int = 0x50524943 // "PRIC"
const OP_CHECK_TARGET: int = 0x54415247 // "TARG"
const OP_REGISTER_TARGET: int = 0x52454754 // "REGT"

// G_Master opcodes
const OP_MINT: int = 21
const OP_CHANGE_ADMIN: int = 3
const OP_CHANGE_CONTENT: int = 4
const OP_FINALIZE_MINT: int = 0x464d494e // "FMIN"

// G_Ecosystem opcodes
const OP_TRANSFER_ECO: int = 0x45434f54 // "ECOT"

// ==================== Token Constants ====================

// Total supply: 99亿 G = 9,900,000,000 * 10^6 base units
const G_TOTAL_SUPPLY: int = 9900000000000000
const G_DECIMALS: int = 6

// Distribution percentages (multiplied for integer math)
// Sale: 10%, Team: 20%, Reserve: 5%, LP: 5%, Ecosystem: 60%
const G_SALE_ALLOCATION: int = 990000000000000 // 10% = 9.9亿 G
const G_TEAM_ALLOCATION: int = 1980000000000000 // 20% = 19.8亿 G
const G_RESERVE_ALLOCATION: int = 495000000000000 // 5% = 4.95亿 G
const G_LP_ALLOCATION: int = 495000000000000 // 5% = 4.95亿 G
const G_ECOSYSTEM_ALLOCATION: int = 5940000000000000 // 60% = 59.4亿 G

// ==================== Price Targets (USD * 10^6) ====================

// Tier 2 (99.99 TON) — 5 rounds, x2.5 per round
const T2_R1_TARGET: uint32 = 0
const T2_R2_TARGET: uint32 = 200
const T2_R3_TARGET: uint32 = 500
const T2_R4_TARGET: uint32 = 1250
const T2_R5_TARGET: uint32 = 3125
const T2_TOTAL_ROUNDS: uint8 = 5

// Tier 3 (299.99 TON) — 10 rounds, x2 per round
const T3_R1_TARGET: uint32 = 0
const T3_R2_TARGET: uint32 = 160
const T3_R3_TARGET: uint32 = 320
const T3_R4_TARGET: uint32 = 640
const T3_R5_TARGET: uint32 = 1280
const T3_R6_TARGET: uint32 = 2560
const T3_R7_TARGET: uint32 = 5120
const T3_R8_TARGET: uint32 = 10240
const T3_R9_TARGET: uint32 = 20480
const T3_R10_TARGET: uint32 = 40960
const T3_TOTAL_ROUNDS: uint8 = 10

// Team vesting — 10 rounds, x3 per round
@pure
fun teamRoundTarget(round: uint8): uint32 {
    if (round == 0) {
        return 0;
    }
    var price: uint32 = 486;
    var i: uint8 = 1;
    while (i < round) {
        price = price * 3;
        i = i + 1;
    }
    return price;
}

const TTM_TOTAL_ROUNDS: uint8 = 10
const T_TEAM_PER_ROUND: int = 198000000000000 // 1.98亿 G per round (20% / 10)
const OP_CONFIGURE_VESTING_AMOUNT: int = 0x41564d54 // "AVMT"

// ==================== 24 hours in seconds ====================

const SECONDS_24H: int = 86400

// ==================== Signature Domain Separation ====================

const SCHEMA_VERSION: uint32 = 1

// ==================== Ed25519 Constants ====================

const ED25519_SIG_BITS: int = 512

// ==================== Jetton Utility Functions ====================

@inline
fun packJettonWalletData(
    balance: int,
    ownerAddress: address,
    jettonMasterAddress: address,
    jettonWalletCode: cell,
): cell {
    return beginCell()
        .storeCoins(balance)
        .storeAddress(ownerAddress)
        .storeAddress(jettonMasterAddress)
        .storeRef(jettonWalletCode)
        .endCell();
}

@inline
fun calculateJettonWalletStateInit(
    ownerAddress: address,
    jettonMasterAddress: address,
    jettonWalletCode: cell,
): cell {
    var dataCell: cell = packJettonWalletData(
        0,
        ownerAddress,
        jettonMasterAddress,
        jettonWalletCode,
    );
    return beginCell()
        .storeUint(0, 2)
        .storeMaybeRef(jettonWalletCode)
        .storeMaybeRef(dataCell)
        .storeUint(0, 1)
        .endCell();
}

fun calculateJettonWalletAddress(walletStateInit: cell): address {
    return address.fromWorkchainAndHash(basechainWorkchain(), walletStateInit.hash());
}
