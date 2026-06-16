import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

// ==================== CONFIGURATION (paste your addresses here) ====================

// Reserve wallet: 0QDsx-vPapMJyIh3LYEQXAF_wp0iAWk8I6ZN7Vw79zqTDIjo
// LP wallet:      0QB31HYfGtzDDa-cudZolA6g1gNcoxZsxeQoEM4lmhhuoyvk

fun main() {
    val deployer = scripts.wallet("deployer");
    println("=== G Token Initialization ===");
    println("Admin: {}", deployer.address);
    println("");

    // ========== DEPLOYED TESTNET v0.2 ADDRESSES (abcacb5) ==========
    val masterAddress = makeAddr(0x3e224893a657faab66c18d10e2db3b0715624f9159f61d33e90aeacf764c7398);
    val oracleAddress = makeAddr(0x5dea656b8002bc2702db9e667678e5fdb87004d50f06f8f1cf4f7172bcfaf092);
    val saleAddress = makeAddr(0x93ec5fac5ab1a1285161e7b8fd24a88097d30b6c719ab5c028963b86274270ef);
    val teamAddress = makeAddr(0x76589a9f497384490a3b74a511003cf165b8c50c35f0779dda3a06afd6c13bad);
    val ecoAddress = makeAddr(0x938f6787b0cf2e608345ff90d5a25076ca56ade3c517d78d59a3a5508197f1e9);

    // Jetton wallet addresses (calculated via Master.getWalletAddress)
    val saleWallet = makeAddr(0xeef1d9ded153b2240a51297221dc41437059f15d7f011d2eb0aae4903e0d7c5e);
    val teamWallet = makeAddr(0xc14f99484dcfad1f24184d1fca93af67069680877b0854ee96012b5ef98dcde7);
    val ecoWallet = makeAddr(0x1dcda469d263cbd4ecb6281e9db5ce9368c86fb530ddb7a3baa78d0c8da694c5);

    // Direct wallet addresses (do NOT use Jetton wallet addresses here)
    val reserveWallet = makeAddr(0xecc7ebcf6a9309c888772d81105c017fc29d2201693c23a64ded5c3bf73a930c);
    val lpWallet = makeAddr(0x77d4761f1adcc30daf9cb9d668940ea0d6035ca3166cc5e42810ce259a186ea3);

    // Backend Ed25519 public key (dev seed)
    val pubKey: uint256 = 0xa7954053e8f7dad6003bfb9316aa105646dcad54ae6ee81770a5c25a36197c4b;
    // ================================================================

    // ====== Safety guards: all addresses must be updated ======
    var ok: bool = true;

    if (masterAddress == deployer.address) {
        println("ERROR: masterAddress not updated");
        ok = false;
    }
    if (oracleAddress == deployer.address) {
        println("ERROR: oracleAddress not updated");
        ok = false;
    }
    if (saleAddress == deployer.address) {
        println("ERROR: saleAddress not updated");
        ok = false;
    }
    if (teamAddress == deployer.address) {
        println("ERROR: teamAddress not updated");
        ok = false;
    }
    if (ecoAddress == deployer.address) {
        println("ERROR: ecoAddress not updated");
        ok = false;
    }
    if (saleWallet == deployer.address) {
        println("ERROR: saleWallet not updated");
        ok = false;
    }
    if (teamWallet == deployer.address) {
        println("ERROR: teamWallet not updated");
        ok = false;
    }
    if (ecoWallet == deployer.address) {
        println("ERROR: ecoWallet not updated");
        ok = false;
    }
    if (reserveWallet == deployer.address) {
        println("ERROR: reserveWallet not updated");
        ok = false;
    }
    if (lpWallet == deployer.address) {
        println("ERROR: lpWallet not updated");
        ok = false;
    }

    if (pubKey == 0) {
        println("ERROR: pubKey not updated (still 0)");
        ok = false;
    }
    if (reserveWallet == lpWallet) {
        println("ERROR: reserveWallet == lpWallet (must be different)");
        ok = false;
    }
    if (saleWallet == teamWallet || saleWallet == ecoWallet || teamWallet == ecoWallet) {
        println("ERROR: sale/team/eco Jetton wallets must be different");
        ok = false;
    }

    if (!ok) {
        println("");
        println("Update all TODO placeholders above, then re-run.");
        return;
    }

    println("All address guards passed — starting initialization...");

    stepAll(
        saleAddress,
        teamAddress,
        ecoAddress,
        oracleAddress,
        masterAddress,
        saleWallet,
        teamWallet,
        ecoWallet,
        reserveWallet,
        lpWallet,
        pubKey,
    );

    println("");
    println("All steps complete. Run verify_deployment.tolk next.");
}

// ==================== Helpers ====================

fun sendTo(dest: address, body: cell, value: coins) {
    val deployer = scripts.wallet("deployer");
    val res = net.send(
        deployer.address,
        createMessage({ bounce: BounceMode.NoBounce, value, dest, body }),
    );
    res.waitForFirstTransaction();
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

fun bodyMint(toAddress: address, amount: coins, deployFee: coins): cell {
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
        .storeCoins(deployFee)
        .storeRef(internalTransferBody)
        .endCell();
}

// ==================== Main init flow ====================

fun stepAll(
    saleAddress: address,
    teamAddress: address,
    ecoAddress: address,
    oracleAddress: address,
    masterAddress: address,
    saleWallet: address,
    teamWallet: address,
    ecoWallet: address,
    reserveWallet: address,
    lpWallet: address,
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

    println("--- Step 5: Configure Team Vesting Amount ---");
    sendTo(teamAddress, bodyConfigVestingAmount(T_TEAM_PER_ROUND), ton("0.05"));

    println("--- Step 6: Register Oracle Targets (23 targets) ---");
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

    println("--- Step 7: Set Initial Price $0.000162 ---");
    sendTo(oracleAddress, bodyUpdatePrice(162), ton("0.05"));

    println("--- Step 8: Mint 99亿 G to Admin Wallet ---");
    val walletDeployFee: coins = ton("0.05");
    val adminAddr = scripts.wallet("deployer").address;
    println("  Admin: {}", adminAddr);
    println("  Wallet deploy fee: {} nanoton", walletDeployFee);
    sendTo(
        masterAddress,
        bodyMint(adminAddr, G_TOTAL_SUPPLY, walletDeployFee),
        ton("0.15"),
    );

    println("--- Step 9: Finalize Mint (lock supply) ---");
    sendTo(masterAddress, bodyFinalizeMint(), ton("0.05"));

    println("");
    println("=== Init Complete ===");
    println("99亿 G minted to admin wallet. Run distribute.tolk to allocate.");
}
