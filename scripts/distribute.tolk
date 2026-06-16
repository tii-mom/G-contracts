import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"
import "@wrappers/GMaster.gen"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

// ==================== CONFIGURATION ====================
// Run after init_all.tolk completes successfully.

fun main() {
    val deployer = scripts.wallet("deployer");
    println("=== G Token Distribution ===");
    println("Admin: {}", deployer.address);
    println("");

    // v0.2 contract addresses
    val masterAddress = makeAddr(0x3e224893a657faab66c18d10e2db3b0715624f9159f61d33e90aeacf764c7398);
    val saleAddress = makeAddr(0x93ec5fac5ab1a1285161e7b8fd24a88097d30b6c719ab5c028963b86274270ef);
    val teamAddress = makeAddr(0x76589a9f497384490a3b74a511003cf165b8c50c35f0779dda3a06afd6c13bad);
    val ecoAddress = makeAddr(0x938f6787b0cf2e608345ff90d5a25076ca56ade3c517d78d59a3a5508197f1e9);
    val reserveAddress = makeAddr(0xecc7ebcf6a9309c888772d81105c017fc29d2201693c23a64ded5c3bf73a930c);
    val lpAddress = makeAddr(0x77d4761f1adcc30daf9cb9d668940ea0d6035ca3166cc5e42810ce259a186ea3);

    val master = GMaster { address: masterAddress };
    val adminJW = master.getWalletAddress(deployer.address);
    println("Admin Jetton wallet: {}", adminJW);
    println("");

    distribute(adminJW, saleAddress, G_SALE_ALLOCATION, "Sale (9.9亿)");
    distribute(adminJW, teamAddress, G_TEAM_ALLOCATION, "Team (19.8亿)");
    distribute(adminJW, reserveAddress, G_RESERVE_ALLOCATION, "Reserve (4.95亿)");
    distribute(adminJW, lpAddress, G_LP_ALLOCATION, "LP (4.95亿)");
    distribute(adminJW, ecoAddress, G_ECOSYSTEM_ALLOCATION, "Eco (59.4亿)");

    println("");
    println("=== Distribution Complete ===");
}

fun distribute(adminJW: address, toOwner: address, gAmount: coins, label: string) {
    val deployer = scripts.wallet("deployer");

    // Build OP_TRANSFER body
    val forwardPayload: cell = beginCell().storeUint(0, 32).endCell();
    val transferBody: cell = beginCell()
        .storeUint(OP_TRANSFER, 32)
        .storeUint(0, 64)
        .storeCoins(gAmount)
        .storeAddress(toOwner)
        .storeAddress(deployer.address)
        .storeMaybeRef(null)
        .storeCoins(1)
        .storeSlice(forwardPayload.beginParse())
        .endCell();

    println("{}: transferring...", label);
    val res = net.send(
        deployer.address,
        createMessage({
            bounce: BounceMode.NoBounce,
            value: ton("0.1"),
            dest: adminJW,
            body: transferBody,
        }),
    );
    res.waitForFirstTransaction();
    println("  {} done", label);
}
