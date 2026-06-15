import "@acton/io"
import "@acton/emulation/network"
import "@acton/emulation/scripts"

import "@wrappers/GWallet.gen"

fun makeAddr(h: uint256): address {
    return address.fromWorkchainAndHash(0, h);
}

fun main() {
    val rw = GWallet { address: makeAddr(0x903bd5f5fdcb47375c0bd9e41f4d888b8e6d8411b680ee87a166cad45f98977) };
    val lw = GWallet { address: makeAddr(0x96ecdfe82be6a840621b90e7ec826f4acac75227d37955e9964922cd83242ab) };

    println("Checking new wallets...");
    val (rBal, _rOwner, _rMaster, _rcode) = rw.getWalletData();
    val (lBal, _lOwner, _lMaster, _lcode) = lw.getWalletData();

    println("Reserve balance: {} base units = {} G", rBal, rBal / 1000000);
    println("LP balance:      {} base units = {} G", lBal, lBal / 1000000);
}
