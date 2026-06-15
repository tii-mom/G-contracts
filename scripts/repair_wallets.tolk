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

    // G_Master
    val masterAddr = makeAddr(0x8556f40833d7587b273f038f963513750b151b376bed7dc24907935d8b54258d);
    val master = GMaster { address: masterAddr };

    val (supply, _mintable, _admin, _content, walletCode) = master.getJettonData();
    println("Wallet code obtained. totalSupply = {}", supply);

    // Construct Jetton wallet with 4.95亿 G for Reserve
    val reserveOwner = makeAddr(0xecc7ebcf6a9309c888772d81105c017fc29d2201693c23a64ded5c3bf73a930c);
    val lpOwner = makeAddr(0x77d4761f1adcc30daf9cb9d668940ea0d6035ca3166cc5e42810ce259a186ea3);

    deployWallet(reserveOwner, masterAddr, walletCode, G_RESERVE_ALLOCATION, "Reserve");
    deployWallet(lpOwner, masterAddr, walletCode, G_LP_ALLOCATION, "LP");

    println("Done. Verify with: acton script scripts/check_balances.tolk --net testnet");
}

fun deployWallet(owner: address, master: address, code: cell, gAmount: coins, label: string) {
    val deployer = scripts.wallet("deployer");

    // Build wallet initial data
    val walletData = packJettonWalletData(gAmount, owner, master, code);

    // Build state_init
    val stateInit = beginCell()
        .storeUint(0, 2)
        .storeMaybeRef(code)
        .storeMaybeRef(walletData)
        .storeUint(0, 1)
        .endCell();

    val walletAddr = calculateJettonWalletAddress(stateInit);
    println("{} Jetton wallet: {}", label, walletAddr);

    // Send deploy message with state_init + TON for storage
    val msg = createMessage({
        bounce: BounceMode.NoBounce,
        value: ton("0.1"),
        dest: {
            workchain: 0,
            stateInit: ContractState {
                code,
                data: walletData,
            },
        },
    });
    val res = net.send(deployer.address, msg);
    println("  Deploying {}...", label);
    res.waitForFirstTransaction();
    println("  {} deployed", label);
}
