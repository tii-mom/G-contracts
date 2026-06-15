import "@acton/build"
import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"

fun main() {
    val deployer = scripts.wallet("deployer");
    println("Deployer: {}", deployer.address);

    // ==================== Step 1: Deploy Jetton Content Cell ====================
    // Off-chain metadata per TEP-64: snake-format cell
    val jettonContent = createSnakeCell(
        "https://ivory-keen-perch-796.mypinata.cloud/ipfs/bafybeiexyprggosszryqrqm4kwcnmy7u23n6fc3pbz6ejojqghqdyzx5oq",
    );

    // ==================== Step 2: Get G_Wallet code ====================
    val walletCode: cell = build("G_Wallet");

    // ==================== Step 3: Deploy G_Master ====================
    val masterStorage = beginCell()
        .storeCoins(0)
        .storeAddress(deployer.address)
        .storeBool(false)
        .storeRef(jettonContent)
        .storeRef(walletCode)
        .endCell();

    val masterInit = ContractState {
        code: build("G_Master"),
        data: masterStorage,
    };
    val masterAddr = AutoDeployAddress { stateInit: masterInit }.calculateAddress();

    val masterDeployMsg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { stateInit: masterInit },
    });
    val masterRes = net.send(deployer.address, masterDeployMsg);
    println("G_Master deploy: {}", masterRes);

    println("G_Master deployed at: {}", masterAddr);

    // ==================== Step 4: Deploy PriceOracle ====================
    val oracleStorage = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 32)
        .storeUint(0, 32)
        .storeRef(createEmptyCell())
        .endCell();

    val oracleInit = ContractState {
        code: build("PriceOracle"),
        data: oracleStorage,
    };
    val oracleAddr = AutoDeployAddress { stateInit: oracleInit }.calculateAddress();

    val oracleDeployMsg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { stateInit: oracleInit },
    });
    val oracleRes = net.send(deployer.address, oracleDeployMsg);
    println("PriceOracle deploy: {}", oracleRes);

    println("PriceOracle deployed at: {}", oracleAddr);

    // ==================== Step 5: Deploy G_Sale ====================
    // Initial storage: owner | backendPublicKey(0 for now) | paused(false) | oracleAddress
    val saleStorage = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeBool(false)
        .storeAddress(oracleAddr)
        .storeRef(
            beginCell().storeAddressOpt(null).storeMaybeRef(null).endCell(),
        )
        .storeRef(
            beginCell()
                .storeMaybeRef(null)
                .storeMaybeRef(null)
                .storeMaybeRef(null)
                .storeMaybeRef(null)
                .endCell(),
        )
        .storeMaybeRef(null)
        .endCell();

    val saleInit = ContractState {
        code: build("G_Sale"),
        data: saleStorage,
    };
    val saleAddr = AutoDeployAddress { stateInit: saleInit }.calculateAddress();

    val saleDeployMsg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { stateInit: saleInit },
    });
    val saleRes = net.send(deployer.address, saleDeployMsg);
    println("G_Sale deploy: {}", saleRes);

    println("G_Sale deployed at: {}", saleAddr);

    // ==================== Step 6: Deploy G_TeamVesting ====================
    val teamStorage = beginCell()
        .storeAddress(deployer.address)
        .storeUint(0, 256)
        .storeCoins(T_TEAM_PER_ROUND)
        .storeUint(0, 16)
        .storeRef(
            beginCell().storeAddress(deployer.address).storeAddress(oracleAddr).endCell(),
        )
        .storeMaybeRef(null)
        .endCell();

    val teamInit = ContractState {
        code: build("G_TeamVesting"),
        data: teamStorage,
    };
    val teamAddr = AutoDeployAddress { stateInit: teamInit }.calculateAddress();

    val teamDeployMsg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { stateInit: teamInit },
    });
    val teamRes = net.send(deployer.address, teamDeployMsg);
    println("G_TeamVesting deploy: {}", teamRes);

    println("G_TeamVesting deployed at: {}", teamAddr);

    // ==================== Step 7: Deploy G_Ecosystem ====================
    val ecoStorage = beginCell()
        .storeAddress(deployer.address)
        .storeAddress(deployer.address)
        .storeCoins(59400000000000000)
        .endCell();

    val ecoInit = ContractState {
        code: build("G_Ecosystem"),
        data: ecoStorage,
    };
    val ecoAddr = AutoDeployAddress { stateInit: ecoInit }.calculateAddress();

    val ecoDeployMsg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { stateInit: ecoInit },
    });
    val ecoRes = net.send(deployer.address, ecoDeployMsg);
    println("G_Ecosystem deploy: {}", ecoRes);

    println("G_Ecosystem deployed at: {}", ecoAddr);

    // ==================== Summary ====================
    println("");
    println("===== Deployment Summary =====");
    println("G_Master:     {}", masterAddr);
    println("PriceOracle:  {}", oracleAddr);
    println("G_Sale:       {}", saleAddr);
    println("G_TeamVesting: {}", teamAddr);
    println("G_Ecosystem:  {}", ecoAddr);
    println("");
    println("===== Jetton Wallet Configuration =====");
    println("");
    println("Each contract needs its own Jetton wallet to hold and transfer G tokens.");
    println("Use G_Master.get_wallet_address(contractAddress) to calculate:");
    println("  Sale wallet:   Master.getWalletAddress(saleAddr)");
    println("  Team wallet:   Master.getWalletAddress(teamAddr)");
    println("  Ecosystem wallet: Master.getWalletAddress(ecoAddr)");
    println("");
    println("===== Post-deploy Steps =====");
    println("");
    println("1. Register price targets in PriceOracle:");
    println("   PriceOracle.batchRegister([0, 200, 500, 1250, 3125, 160, 320, 640, 1280, 2560, 5120, 10240, 20480, 40960, 486, 1458, 4374, 13122, 39366, 118098, 354294, 1062882, 3188646])");
    println("");
    println("2. Configure G_Sale backend key + jetton wallet:");
    println("   Sale.configureBackendKey(backendPubKey)");
    println("   Sale.configureJettonWallet(saleWalletAddr)");
    println("   Sale.configureOracle(oracleAddr)");
    println("");
    println("3. Configure G_Sale tiers (ATIR):");
    println("   Tier1: 9.99 TON, 50K G, 1 round, no invite");
    println("   Tier2: 99.99 TON, 1.2M G, 5 rounds, invite required");
    println("   Tier3: 299.99 TON, 5M G, 10 rounds, invite required");
    println("");
    println("4. Configure G_TeamVesting:");
    println("   Team.configureJettonWallet(teamWalletAddr)");
    println("   Team.configureOracle(oracleAddr)");
    println("");
    println("5. Configure G_Ecosystem:");
    println("   Eco.configureJettonWallet(ecoWalletAddr)");
    println("");
    println("6. G_Master.mint() to distribute 99B G:");
    println("   Master.mint(to: saleWalletAddr, amount: 9.9B)");
    println("   Master.mint(to: teamWalletAddr, amount: 19.8B)");
    println("   Master.mint(to: reserveWallet, amount: 4.95B)");
    println("   Master.mint(to: lpWallet, amount: 4.95B)");
    println("   Master.mint(to: ecoWalletAddr, amount: 59.4B)");
    println("");
    println("7. PriceOracle.updatePrice(162) ← set initial price $0.000162");
}

fun createSnakeCell(data: string): cell {
    return beginCell().storeString(data).endCell();
}
