import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"
import "@wrappers/GMaster.gen"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

fun main() {
    val deployer = scripts.wallet("deployer");
    val masterAddr = makeAddr(0x8556f40833d7587b273f038f963513750b151b376bed7dc24907935d8b54258d);
    val master = GMaster { address: masterAddr };
    var (supply, _mintable, _admin, _content, walletCode) = master.getJettonData();

    println("totalSupply: {} base", supply);
    println("");

    // Sale owner = G_Sale contract
    val saleOwner = makeAddr(0x93ec5fac5ab1a1285161e7b8fd24a88097d30b6c719ab5c028963b86274270ef);
    // Team owner = G_TeamVesting contract
    val teamOwner = makeAddr(0x76589a9f497384490a3b74a511003cf165b8c50c35f0779dda3a06afd6c13bad);
    // Eco owner = G_Ecosystem contract
    val ecoOwner = makeAddr(0x938f6787b0cf2e608345ff90d5a25076ca56ade3c517d78d59a3a5508197f1e9);

    val saleWallet = deployWallet(saleOwner, masterAddr, walletCode, G_SALE_ALLOCATION, "Sale");
    val teamWallet = deployWallet(teamOwner, masterAddr, walletCode, G_TEAM_ALLOCATION, "Team");
    val ecoWallet = deployWallet(ecoOwner, masterAddr, walletCode, G_ECOSYSTEM_ALLOCATION, "Eco");

    println("");
    println("=== New wallet addresses (update configureJettonWallet) ===");
    println("Sale: {}", saleWallet);
    println("Team: {}", teamWallet);
    println("Eco:  {}", ecoWallet);
}

fun deployWallet(owner: address, master: address, code: cell, amount: coins, label: string): address {
    val deployer = scripts.wallet("deployer");
    val data = packJettonWalletData(amount, owner, master, code);
    val stateInit = ContractState { code, data };

    val msg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: { workchain: 0, stateInit },
    });

    val addr = AutoDeployAddress { stateInit }.calculateAddress();
    println("Deploying {} wallet: {} ({} base units)", label, addr, amount);
    val res = net.send(deployer.address, msg);
    res.waitForFirstTransaction();
    println("  {} deployed ✓", label);
    return addr;
}
