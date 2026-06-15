import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@wrappers/GMaster.gen"
import "@wrappers/GWallet.gen"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

fun main() {
    val master = GMaster {
        address: makeAddr(0x8556f40833d7587b273f038f963513750b151b376bed7dc24907935d8b54258d),
    };

    // Reserve wallet onwer
    val reserveOwner = makeAddr(0xecc7ebcf6a9309c888772d81105c017fc29d2201693c23a64ded5c3bf73a930c);
    // LP wallet owner
    val lpOwner = makeAddr(0x77d4761f1adcc30daf9cb9d668940ea0d6035ca3166cc5e42810ce259a186ea3);

    val reserveWallet = master.getWalletAddress(reserveOwner);
    val lpWallet = master.getWalletAddress(lpOwner);

    println("Reserve Owner: 0QDsx-vPapMJyIh3LYEQXAF_wp0iAWk8I6ZN7Vw79zqTDIjo");
    println("  Jetton wallet: {}", reserveWallet);
    println("LP Owner: 0QB31HYfGtzDDa-cudZolA6g1gNcoxZsxeQoEM4lmhhuoyvk");
    println("  Jetton wallet: {}", lpWallet);

    // Check wallet balances
    val rw = GWallet { address: reserveWallet };
    val lw = GWallet { address: lpWallet };

    val (rBal, rOwner, rMaster, _rcode) = rw.getWalletData();
    val (lBal, lOwner, lMaster, _lcode) = lw.getWalletData();

    println("");
    println("Reserve Jetton wallet balance: {} base units = {} G", rBal, rBal / 1000000);
    println("LP Jetton wallet balance:      {} base units = {} G", lBal, lBal / 1000000);
}
