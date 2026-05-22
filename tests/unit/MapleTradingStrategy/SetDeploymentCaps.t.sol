// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetDeploymentCapsFailureTests is TestBase {

    address strategyDelegate = makeAddr("strategyDelegate");

    function test_setDeploymentCaps_revert_functionPaused() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);
        globals.__setIsFunctionPaused(MapleTradingStrategy.setDeploymentCaps.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_zeroLength() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:ZERO_LENGTH");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_lengthMismatch() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:LENGTH_MISMATCH");
        strategy.setDeploymentCaps(new address[](2), new uint256[](1));

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:LENGTH_MISMATCH");
        strategy.setDeploymentCaps(new address[](1), new uint256[](2));
    }

    function test_setDeploymentCaps_revert_invalidDeployer() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        address validDeployer1  = makeAddr("validDeployer1");
        address validDeployer2  = makeAddr("validDeployer2");
        address invalidDeployer = makeAddr("invalidDeployer");

        globals.__setIsValidTradingAddress(validDeployer1, true);
        globals.__setIsValidTradingAddress(validDeployer2, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:INVALID_DEPLOYER");
        strategy.setDeploymentCaps(
            array(validDeployer1, validDeployer2, invalidDeployer),
            array(100e6,          200e6,          300e6)
        );

        assertEq(strategy.deploymentCapOf(validDeployer1),  0);
        assertEq(strategy.deploymentCapOf(validDeployer2),  0);
        assertEq(strategy.deploymentCapOf(invalidDeployer), 0);
    }

    function test_setDeploymentCaps_revert_invalidDeployer_revokedDeployer() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        address deployer = makeAddr("deployer");

        globals.__setIsValidTradingAddress(deployer, true);

        assertEq(strategy.deploymentCapOf(deployer), 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer), array(100e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);

        globals.__setIsValidTradingAddress(deployer, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:INVALID_DEPLOYER");
        strategy.setDeploymentCaps(array(deployer), array(50e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);
    }

    function test_setDeploymentCaps_revert_noChange_sameCap() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        address deployer = makeAddr("deployer");

        globals.__setIsValidTradingAddress(deployer, true);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer), array(100e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(deployer), array(100e6));
    }

    function test_setDeploymentCaps_revert_noChange_neverCappedZero() external {
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        address whitelistedDeployer = makeAddr("whitelistedDeployer");
        address blacklistedDeployer = makeAddr("blacklistedDeployer");

        globals.__setIsValidTradingAddress(whitelistedDeployer, true);

        assertEq(strategy.deploymentCapOf(whitelistedDeployer), 0);
        assertEq(strategy.deploymentCapOf(blacklistedDeployer), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(whitelistedDeployer), array(uint256(0)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(blacklistedDeployer), array(uint256(0)));
    }

}

contract SetDeploymentCapsSuccessTests is TestBase {

    address operationalAdmin = makeAddr("operationalAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

    address deployer1 = makeAddr("deployer1");
    address deployer2 = makeAddr("deployer2");
    address deployer3 = makeAddr("deployer3");

    function setUp() public override {
        super.setUp();

        globals.__setOperationalAdmin(operationalAdmin);
        globals.__setStrategyDelegateOf(address(manager), strategyDelegate);

        globals.__setIsValidTradingAddress(deployer1, true);
        globals.__setIsValidTradingAddress(deployer2, true);
        globals.__setIsValidTradingAddress(deployer3, true);
    }

    function test_setDeploymentCaps_success_singleAddress() external {
        uint256 cap = 100e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);
        assertEq(strategy.deploymentCapOf(deployer2), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, cap);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(cap));

        assertEq(strategy.deploymentCapOf(deployer1), cap);
        assertEq(strategy.deploymentCapOf(deployer2), 0);
    }

    function test_setDeploymentCaps_success_multipleAddresses() external {
        uint256 cap1 = 100e6;
        uint256 cap2 = 250e6;
        uint256 cap3 = 500e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);
        assertEq(strategy.deploymentCapOf(deployer2), 0);
        assertEq(strategy.deploymentCapOf(deployer3), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, cap1);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer2, cap2);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer3, cap3);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1, deployer2, deployer3), array(cap1, cap2, cap3));

        assertEq(strategy.deploymentCapOf(deployer1), cap1);
        assertEq(strategy.deploymentCapOf(deployer2), cap2);
        assertEq(strategy.deploymentCapOf(deployer3), cap3);
    }

    function test_setDeploymentCaps_success_duplicateAddress() external {
        uint256 cap1 = 100e6;
        uint256 cap2 = 250e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, cap1);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, cap2);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1, deployer1), array(cap1, cap2));

        assertEq(strategy.deploymentCapOf(deployer1), cap2);
    }

    function test_setDeploymentCaps_success_overwriteExistingCap_increase() external {
        uint256 initialCap = 100e6;

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(initialCap));

        assertEq(strategy.deploymentCapOf(deployer1), initialCap);

        uint256 updatedCap = 250e6;

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, updatedCap);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(updatedCap));

        assertEq(strategy.deploymentCapOf(deployer1), updatedCap);
    }

    function test_setDeploymentCaps_success_overwriteExistingCap_decrease() external {
        uint256 initialCap = 250e6;

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(initialCap));

        assertEq(strategy.deploymentCapOf(deployer1), initialCap);

        uint256 updatedCap = 100e6;

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, updatedCap);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(updatedCap));

        assertEq(strategy.deploymentCapOf(deployer1), updatedCap);
    }

    function test_setDeploymentCaps_success_calledByOperationalAdmin() external {
        uint256 cap = 100e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, cap);

        vm.prank(operationalAdmin);
        strategy.setDeploymentCaps(array(deployer1), array(cap));

        assertEq(strategy.deploymentCapOf(deployer1), cap);
    }

    function test_setDeploymentCaps_success_zeroCap() external {
        uint256 initialCap = 100e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(initialCap));

        assertEq(strategy.deploymentCapOf(deployer1), initialCap);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(deployer1, 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(uint256(0)));

        assertEq(strategy.deploymentCapOf(deployer1), 0);
    }

    function test_setDeploymentCaps_success_revokedDeployer_zeroCap() external {
        address revokedDeployer = makeAddr("revokedDeployer");

        globals.__setIsValidTradingAddress(revokedDeployer, true);

        uint256 cap = 100e6;

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(revokedDeployer), array(cap));

        assertEq(strategy.deploymentCapOf(revokedDeployer), cap);

        globals.__setIsValidTradingAddress(revokedDeployer, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.DeploymentCapSet(revokedDeployer, 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(revokedDeployer), array(uint256(0)));

        assertEq(strategy.deploymentCapOf(revokedDeployer), 0);
    }

}
