import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"

import "@wrappers/GEcosystem.gen"
import "@wrappers/GMaster.gen"
import "@wrappers/GSale.gen"
import "@wrappers/GTeamVesting.gen"
import "@wrappers/GWallet.gen"
import "@wrappers/PriceOracle.gen"

// ==================== G_Wallet Tests ====================

get fun `test G_Wallet deploy successfully`() {
    val deployer = testing.treasury("deployer");
    val contract = GWallet.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("0.1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}

// ==================== G_Master Tests ====================

get fun `test G_Master deploy successfully`() {
    val deployer = testing.treasury("deployer");
    val contract = GMaster.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}

// ==================== G_Sale Tests ====================

get fun `test G_Sale deploy successfully`() {
    val deployer = testing.treasury("deployer");
    val contract = GSale.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}

// ==================== PriceOracle Tests ====================

get fun `test PriceOracle deploy successfully`() {
    val deployer = testing.treasury("deployer");
    val contract = PriceOracle.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("0.5") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}

// ==================== G_TeamVesting Tests ====================

get fun `test G_TeamVesting deploy and getter`() {
    val deployer = testing.treasury("deployer");
    val contract = GTeamVesting.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}

// ==================== G_Ecosystem Tests ====================

get fun `test G_Ecosystem deploy and getter`() {
    val deployer = testing.treasury("deployer");
    val contract = GEcosystem.fromStorage();

    val res = contract.deploy(deployer.address, { value: ton("1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });
}
