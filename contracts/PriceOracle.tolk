import "@stdlib/tvm-dicts"
import "types"

contract PriceOracle {
    author: "tii-mom"
    version: "1.0.0"
    description: "G Token USD price oracle — admin-updated with target price tracking"
}

const OP_REGISTER_TARGET: int = 0x52454754 // "REGT"
const OP_BATCH_REGISTER: int = 0x42524547 // "BREG"

// ==================== Storage ====================

// admin_address | current_price_usd(uint32) | updated_at(uint32) | ^targets dict<uint32, first_reach:uint32>

struct OracleStorage {
    adminAddress: address
    currentPriceUsd: uint32
    updatedAt: uint32
    targetsCell: cell? // dict<uint32, uint32> — targetPrice => firstReachTime
}

fun OracleStorage.load(): OracleStorage {
    var ds: slice = contract.getData().beginParse();
    return OracleStorage {
        adminAddress: ds.loadAddress(),
        currentPriceUsd: ds.loadUint(32),
        updatedAt: ds.loadUint(32),
        targetsCell: ds.loadMaybeRef(),
    };
}

fun OracleStorage.save(self) {
    contract.setData(
        beginCell()
            .storeAddress(self.adminAddress)
            .storeUint(self.currentPriceUsd, 32)
            .storeUint(self.updatedAt, 32)
            .storeMaybeRef(self.targetsCell)
            .endCell(),
    );
}

// ==================== Message Handlers ====================

fun onInternalMessage(in: InMessage) {
    if (in.body.isEmpty()) {
        return;
    }

    var cs: slice = in.body;
    val op: int = cs.loadUint(32);
    val _queryId: int = cs.loadUint(64);

    if (op == OP_UPDATE_PRICE) {
        handleUpdatePrice(cs, in.senderAddress);
        return;
    }
    if (op == OP_REGISTER_TARGET) {
        handleRegisterTarget(cs, in.senderAddress);
        return;
    }
    if (op == OP_BATCH_REGISTER) {
        handleBatchRegister(cs, in.senderAddress);
        return;
    }
    throw Errors.InvalidMessage;
}

fun onBouncedMessage(_in: InMessageBounced) {}

// ==================== Update Price ====================

fun handleUpdatePrice(cs: slice, sender: address) {
    var storage: OracleStorage = OracleStorage.load();
    assert (sender == storage.adminAddress) throw Errors.NotOwner;

    val newPrice: uint32 = cs.loadUint(32);
    val nowTime: uint32 = blockchain.now();

    // Update all registered target first_reach times
    var targets: cell? = storage.targetsCell;
    if (targets != null) {
        var updated: cell? = null;
        var pivot: int = -1;
        var keepGoing: bool = true;

        while (keepGoing) {
            var (nextKey, nextVal, found) = targets.uDictGetNext(32, pivot);
            if (found) {
                var targetPrice: uint32 = nextKey!;
                var oldReach: uint32;
                if (nextVal != null) {
                    oldReach = nextVal.loadUint(32);
                } else {
                    oldReach = 0;
                }
                var newReach: uint32;
                if (newPrice >= targetPrice) {
                    if (oldReach == 0) {
                        newReach = nowTime;
                    } else {
                        newReach = oldReach;
                    }
                } else {
                    newReach = 0;
                }
                var valCell: cell = beginCell().storeUint(newReach, 32).endCell();
                if (updated == null) {
                    updated = null;
                }
                updated.uDictSetRef(32, targetPrice, valCell);
                pivot = targetPrice;
            } else {
                keepGoing = false;
            }
        }

        storage.targetsCell = updated;
    }

    storage.currentPriceUsd = newPrice;
    storage.updatedAt = nowTime;
    storage.save();
}

// ==================== Register Single Target ====================

fun handleRegisterTarget(cs: slice, sender: address) {
    var storage: OracleStorage = OracleStorage.load();
    assert (sender == storage.adminAddress) throw Errors.NotOwner;

    val targetPrice: uint32 = cs.loadUint(32);
    var targets: cell? = storage.targetsCell;
    var valCell: cell = beginCell().storeUint(0, 32).endCell();
    if (targets == null) {
        targets = null;
    }
    targets.uDictSetRef(32, targetPrice, valCell);
    storage.targetsCell = targets;
    storage.save();
}

// ==================== Batch Register Targets ====================

// Accepts a cell containing sequential pairs: targetPrice(32) | dummy(0)... repeated
fun handleBatchRegister(cs: slice, sender: address) {
    var storage: OracleStorage = OracleStorage.load();
    assert (sender == storage.adminAddress) throw Errors.NotOwner;

    var targets: cell? = storage.targetsCell;
    var targetsCell: cell = cs.loadRef();
    var targetsDs: slice = targetsCell.beginParse();

    while (targetsDs.remainingBitsCount() >= 32) {
        val targetPrice: uint32 = targetsDs.loadUint(32);
        var valCell: cell = beginCell().storeUint(0, 32).endCell();
        if (targets == null) {
            targets = null;
        }
        targets.uDictSetRef(32, targetPrice, valCell);
    }

    storage.targetsCell = targets;
    storage.save();
}

// ==================== Getters ====================

get fun get_current_price(): (uint32, uint32) {
    val storage: OracleStorage = OracleStorage.load();
    return (storage.currentPriceUsd, storage.updatedAt);
}

get fun check_target(targetPrice: uint32): (bool, uint32) {
    val storage: OracleStorage = OracleStorage.load();

    if (targetPrice == 0) {
        return (true, blockchain.now());
    }

    var priceMet: bool = (storage.currentPriceUsd >= targetPrice);
    var firstReach: uint32 = 0;

    if (storage.targetsCell != null) {
        var (valCell, found) = storage.targetsCell!.uDictGetRef(32, targetPrice);
        if (found) {
            var valDs: slice = valCell!.beginParse();
            // Value format: uint32 (first_reach_time_bits)
            // We check if there's enough data
            if (valDs.remainingBitsCount() >= 32) {
                firstReach = valDs.loadUint(32);
            }
        }
    }

    return (priceMet, firstReach);
}
