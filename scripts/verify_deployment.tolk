import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"
import "@wrappers/GEcosystem.gen"
import "@wrappers/GMaster.gen"
import "@wrappers/GTeamVesting.gen"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

// ==================== CONFIGURATION (deployed testnet addresses) ====================

fun main() {
    val deployer = scripts.wallet("deployer");
    println("=== G Token Deployment Verification ===");
    println("");

    val masterAddress = makeAddr(0x8556f40833d7587b273f038f963513750b151b376bed7dc24907935d8b54258d);
    val oracleAddress = makeAddr(0x5dea656b8002bc2702db9e667678e5fdb87004d50f06f8f1cf4f7172bcfaf092);
    val saleAddress = makeAddr(0x93ec5fac5ab1a1285161e7b8fd24a88097d30b6c719ab5c028963b86274270ef);
    val teamAddress = makeAddr(0x76589a9f497384490a3b74a511003cf165b8c50c35f0779dda3a06afd6c13bad);
    val ecoAddress = makeAddr(0x938f6787b0cf2e608345ff90d5a25076ca56ade3c517d78d59a3a5508197f1e9);

    var allOk: bool = true;

    allOk = verifyMaster(masterAddress) && allOk;
    allOk = verifyTeamVesting(teamAddress) && allOk;
    allOk = verifyEcosystem(ecoAddress) && allOk;

    println("");
    if (allOk) {
        println("=== All Checks Passed ===");
    } else {
        println("=== SOME CHECKS FAILED — review above ===");
    }
}

// ==================== Verify G_Master ====================

fun verifyMaster(masterAddr: address): bool {
    println("--- G_Master ---");
    val master = GMaster { address: masterAddr };

    val (supply, _mintable, _admin, _content, _code) = master.getJettonData();
    println("  totalSupply: {} base units", supply);
    println("  Expected:     {} base units", G_TOTAL_SUPPLY);

    if (supply == G_TOTAL_SUPPLY) {
        println("  ✓ totalSupply matches");
        return true;
    } else {
        println("  ✗ totalSupply MISMATCH");
        return false;
    }
}

// ==================== Verify G_TeamVesting ====================

fun verifyTeamVesting(teamAddr: address): bool {
    println("--- G_TeamVesting ---");
    val team = GTeamVesting { address: teamAddr };

    val (_owner, _oracle, perRound, _claimed) = team.getVestingData();
    println("  perRound: {} base units", perRound);
    println("  Expected: {} base units", T_TEAM_PER_ROUND);

    if (perRound == T_TEAM_PER_ROUND) {
        println("  ✓ perRound matches");
        return true;
    } else {
        println("  ✗ perRound MISMATCH");
        return false;
    }
}

// ==================== Verify G_Ecosystem ====================

fun verifyEcosystem(ecoAddr: address): bool {
    println("--- G_Ecosystem ---");
    val eco = GEcosystem { address: ecoAddr };

    val (_owner, _wallet, remaining) = eco.getEcoData();
    println("  remainingG: {} base units", remaining);
    println("  Expected:   {} base units", G_ECOSYSTEM_ALLOCATION);

    if (remaining == G_ECOSYSTEM_ALLOCATION) {
        println("  ✓ remainingG matches");
        return true;
    } else {
        println("  ✗ remainingG MISMATCH");
        return false;
    }
}
