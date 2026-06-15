import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@wrappers/GMaster.gen"

fun main() {
    // Deployed addresses (workchain=0, hash decoded from bounceable address)
    val masterAddr = makeAddr(0x8556f40833d7587b273f038f963513750b151b376bed7dc24907935d8b54258d);
    val saleAddr = makeAddr(0x93ec5fac5ab1a1285161e7b8fd24a88097d30b6c719ab5c028963b86274270ef);
    val teamAddr = makeAddr(0x76589a9f497384490a3b74a511003cf165b8c50c35f0779dda3a06afd6c13bad);
    val ecoAddr = makeAddr(0x938f6787b0cf2e608345ff90d5a25076ca56ade3c517d78d59a3a5508197f1e9);

    val master = GMaster { address: masterAddr };

    println("Calculating Jetton wallet addresses...");
    val saleWallet = master.getWalletAddress(saleAddr);
    val teamWallet = master.getWalletAddress(teamAddr);
    val ecoWallet = master.getWalletAddress(ecoAddr);

    println("");
    println("=== Jetton Wallet Addresses ===");
    println("Sale wallet: {}", saleWallet);
    println("Team wallet: {}", teamWallet);
    println("Eco wallet:  {}", ecoWallet);
}

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}
