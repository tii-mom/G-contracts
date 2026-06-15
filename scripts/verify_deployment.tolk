import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"
import "@wrappers/GEcosystem.gen"
import "@wrappers/GMaster.gen"
import "@wrappers/GTeamVesting.gen"

// ==================== CONFIGURATION (paste your addresses here) ====================

fun main() {
    val deployer = scripts.wallet("deployer");
    println("=== G Token Deployment Verification ===");
    println("");

    // ========== UPDATE THESE before running ==========
    val masterAddress = deployer.address; // TODO: paste G_Master address
    val oracleAddress = deployer.address; // TODO: paste PriceOracle address
    val saleAddress = deployer.address;   // TODO: paste G_Sale address
    val teamAddress = deployer.address;   // TODO: paste G_TeamVesting address
    val ecoAddress = deployer.address;    // TODO: paste G_Ecosystem address
    // =================================================

    if (masterAddress == deployer.address) {
        println("ERROR: Update contract addresses before running!");
        return;
    }
    println("Addresses confirmed — running verification...");
    println("");

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
