import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"

// ==================== Configuration ====================
// Paste your deployed addresses here before running on testnet/mainnet

fun main() {
    val deployer = scripts.wallet("deployer");
    println("=== G Token Initialization ===");
    println("Admin: {}", deployer.address);
    println("WARNING: Update contract addresses before running on testnet/mainnet!");
}

// ==================== Helpers ====================

fun sendTo(dest: address, body: cell, value: coins) {
    val deployer = scripts.wallet("deployer");
    val res = net.send(
        deployer.address,
        createMessage({
            bounce: BounceMode.NoBounce,
            value,
            dest,
            body,
        }),
    );
    println("  result: {}", res);
}

fun bodyConfigBackendKey(pubKey: uint256): cell {
    return beginCell()
        .storeUint(OP_CONFIGURE_BACKEND_KEY, 32)
        .storeUint(0, 64)
        .storeUint(pubKey, 256)
        .endCell();
}

fun bodyConfigJettonWallet(walletAddr: address): cell {
    return beginCell()
        .storeUint(OP_CONFIGURE_JETTON_WALLET, 32)
        .storeUint(0, 64)
        .storeAddress(walletAddr)
        .endCell();
}

fun bodyConfigOracle(oracle: address): cell {
    return beginCell()
        .storeUint(OP_CONFIGURE_ORACLE, 32)
        .storeUint(0, 64)
        .storeAddress(oracle)
        .endCell();
}

fun bodyConfigVestingAmount(amount: coins): cell {
    return beginCell()
        .storeUint(OP_CONFIGURE_VESTING_AMOUNT, 32)
        .storeUint(0, 64)
        .storeCoins(amount)
        .endCell();
}

fun bodyRegisterTarget(targetPrice: uint32): cell {
    return beginCell()
        .storeUint(OP_REGISTER_TARGET, 32)
        .storeUint(0, 64)
        .storeUint(targetPrice, 32)
        .endCell();
}

fun bodyUpdatePrice(price: uint32): cell {
    return beginCell()
        .storeUint(OP_UPDATE_PRICE, 32)
        .storeUint(0, 64)
        .storeUint(price, 32)
        .endCell();
}

fun bodyFinalizeMint(): cell {
    return beginCell().storeUint(OP_FINALIZE_MINT, 32).storeUint(0, 64).endCell();
}

fun bodyConfigTier(
    tierId: uint8,
    tonAmount: uint64,
    gBaseUnits: uint128,
    totalRounds: uint8,
    roundGAmount: uint128,
    active: bool,
    inviteRequired: bool,
    maxPurchases: uint32,
    targetsCell: cell,
): cell {
    return beginCell()
        .storeUint(OP_CONFIGURE_TIER, 32)
        .storeUint(0, 64)
        .storeUint(tierId, 8)
        .storeUint(tonAmount, 64)
        .storeUint(gBaseUnits, 128)
        .storeUint(totalRounds, 8)
        .storeUint(roundGAmount, 128)
        .storeBool(active)
        .storeBool(inviteRequired)
        .storeRef(targetsCell)
        .storeUint(maxPurchases, 32)
        .endCell();
}

fun bodyMint(toAddress: address, amount: coins): cell {
    val internalTransferBody: cell = beginCell()
        .storeUint(OP_INTERNAL_TRANSFER, 32)
        .storeUint(0, 64)
        .storeCoins(amount)
        .storeAddress(toAddress)
        .storeAddressOpt(null)
        .storeCoins(0)
        .storeSlice(beginCell().storeUint(0, 32).endCell().beginParse())
        .endCell();
    return beginCell()
        .storeUint(OP_MINT, 32)
        .storeUint(0, 64)
        .storeAddress(toAddress)
        .storeCoins(0)
        .storeRef(internalTransferBody)
        .endCell();
}

// ==================== Step ====================

fun stepAll(
    saleAddress: address,
    teamAddress: address,
    ecoAddress: address,
    oracleAddress: address,
    masterAddress: address,
    saleWallet: address,
    teamWallet: address,
    ecoWallet: address,
    pubKey: uint256,
) {
    println("--- Step 1: Configure Backend Keys ---");
    sendTo(saleAddress, bodyConfigBackendKey(pubKey), ton("0.05"));
    sendTo(teamAddress, bodyConfigBackendKey(pubKey), ton("0.05"));

    println("--- Step 2: Configure Jetton Wallets ---");
    sendTo(saleAddress, bodyConfigJettonWallet(saleWallet), ton("0.05"));
    sendTo(teamAddress, bodyConfigJettonWallet(teamWallet), ton("0.05"));
    sendTo(ecoAddress, bodyConfigJettonWallet(ecoWallet), ton("0.05"));

    println("--- Step 3: Configure Oracle ---");
    sendTo(saleAddress, bodyConfigOracle(oracleAddress), ton("0.05"));
    sendTo(teamAddress, bodyConfigOracle(oracleAddress), ton("0.05"));

    println("--- Step 4: Configure Tiers ---");
    val t1Targets: cell = beginCell().storeUint(0, 32).endCell();
    sendTo(
        saleAddress,
        bodyConfigTier(
            1,
            9990000000,
            50000000000,
            1,
            50000000000,
            true,
            false,
            5000,
            t1Targets,
        ),
        ton("0.05"),
    );

    val t2Targets: cell = beginCell()
        .storeUint(0, 32)
        .storeUint(200, 32)
        .storeUint(500, 32)
        .storeUint(1250, 32)
        .storeUint(3125, 32)
        .endCell();
    sendTo(
        saleAddress,
        bodyConfigTier(
            2,
            99990000000,
            1200000000000,
            5,
            240000000000,
            true,
            true,
            200,
            t2Targets,
        ),
        ton("0.05"),
    );

    val t3Targets: cell = beginCell()
        .storeUint(0, 32)
        .storeUint(160, 32)
        .storeUint(320, 32)
        .storeUint(640, 32)
        .storeUint(1280, 32)
        .storeUint(2560, 32)
        .storeUint(5120, 32)
        .storeUint(10240, 32)
        .storeUint(20480, 32)
        .storeUint(40960, 32)
        .endCell();
    sendTo(
        saleAddress,
        bodyConfigTier(
            3,
            299990000000,
            5000000000000,
            10,
            500000000000,
            true,
            true,
            100,
            t3Targets,
        ),
        ton("0.05"),
    );

    println("--- Step 5: Configure Team Vesting ---");
    sendTo(teamAddress, bodyConfigVestingAmount(T_TEAM_PER_ROUND), ton("0.05"));

    println("--- Step 6: Register Oracle Targets ---");
    sendTo(oracleAddress, bodyRegisterTarget(0), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(200), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(500), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(1250), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(3125), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(160), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(320), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(640), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(1280), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(2560), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(5120), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(10240), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(20480), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(40960), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(486), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(1458), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(4374), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(13122), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(39366), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(118098), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(354294), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(1062882), ton("0.02"));
    sendTo(oracleAddress, bodyRegisterTarget(3188646), ton("0.02"));

    println("--- Step 7: Set Initial Price ---");
    sendTo(oracleAddress, bodyUpdatePrice(162), ton("0.05"));

    println("--- Step 8: Mint Distribution ---");
    // Note: Reserve and LP wallets must be manually configured
    sendTo(masterAddress, bodyMint(saleWallet, G_SALE_ALLOCATION), ton("0.1"));
    sendTo(masterAddress, bodyMint(teamWallet, G_TEAM_ALLOCATION), ton("0.1"));
    sendTo(masterAddress, bodyMint(ecoWallet, G_ECOSYSTEM_ALLOCATION), ton("0.1"));

    println("--- Step 9: Finalize Mint ---");
    sendTo(masterAddress, bodyFinalizeMint(), ton("0.05"));

    println("=== Init Complete ===");
}
