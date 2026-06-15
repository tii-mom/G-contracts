import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@contracts/types"

// ==================== G Token Deployment Verification ====================
// Run after deploy_all.tolk and init_all.tolk
// Paste deployed addresses below, then run: acton script scripts/verify_deployment.tolk

fun main() {
    println("=== G Token Deployment Verification ===");
    println("");
    println("Update contract addresses in this file before running!");
    println("");
    println("=== Manual Verification Checklist ===");
    println("");
    println("1. G_Master.get_jetton_data():");
    println("   totalSupply should be {}", G_TOTAL_SUPPLY);
    println("   mintable should be -1 (or 0 after finalize)");
    println("");
    println("2. G_Master.get_wallet_address(saleAddr): verify sale wallet");
    println("   G_Master.get_wallet_address(teamAddr): verify team wallet");
    println("   G_Master.get_wallet_address(ecoAddr): verify eco wallet");
    println("");
    println("3. G_Sale.owner(): should be admin address");
    println("   G_Sale.is_paused(): should be false");
    println("   G_Sale.jetton_wallet(): should be set");
    println("");
    println("4. G_Sale.get_order(someOrderHash): verify order exists");
    println("");
    println("5. G_TeamVesting.get_vesting_data():");
    println("   perRound should be {}", T_TEAM_PER_ROUND);
    println("   claimedMask should be 0 initially");
    println("");
    println("6. G_Ecosystem.get_eco_data():");
    println("   remainingG should be {}", G_ECOSYSTEM_ALLOCATION);
    println("");
    println("7. PriceOracle.get_current_price():");
    println("   price should be 162 (if initialized)");
    println("");
    println("8. All tier configs:");
    println("   Tier1 cap=5000, Tier2 cap=200, Tier3 cap=100");
    println("");
    println("===== End Verification Checklist =====");
}
