// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { MapleAllocationStrategy } from "../../../contracts/MapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetDeploymentCapsFailureTests is TestBase {

    function test_setDeploymentCaps_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAllocationStrategy.setDeploymentCaps.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:LOCKED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_notAuthorized() external {
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_notAuthorized_operationalAdmin() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_zeroLength() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:ZERO_LENGTH");
        strategy.setDeploymentCaps(new address[](0), new uint256[](0));
    }

    function test_setDeploymentCaps_revert_lengthMismatch() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:LENGTH_MISMATCH");
        strategy.setDeploymentCaps(new address[](2), new uint256[](1));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:LENGTH_MISMATCH");
        strategy.setDeploymentCaps(new address[](1), new uint256[](2));
    }

    function test_setDeploymentCaps_revert_invalidDeployer() external {
        address validDeployer1  = makeAddr("validDeployer1");
        address validDeployer2  = makeAddr("validDeployer2");
        address invalidDeployer = makeAddr("invalidDeployer");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", validDeployer1, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", validDeployer2, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:NOT_MAPLE_MANAGED_WALLET");
        strategy.setDeploymentCaps(
            array(validDeployer1, validDeployer2, invalidDeployer),
            array(100e6,          200e6,          300e6)
        );

        assertEq(strategy.deploymentCapOf(validDeployer1),  0);
        assertEq(strategy.deploymentCapOf(validDeployer2),  0);
        assertEq(strategy.deploymentCapOf(invalidDeployer), 0);
    }

    function test_setDeploymentCaps_revert_invalidDeployer_revokedDeployer() external {
        address deployer = makeAddr("deployer");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer, true);

        assertEq(strategy.deploymentCapOf(deployer), 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer), array(100e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:NOT_MAPLE_MANAGED_WALLET");
        strategy.setDeploymentCaps(array(deployer), array(50e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);
    }

    function test_setDeploymentCaps_revert_noChange_sameCap() external {
        address deployer = makeAddr("deployer");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer, true);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer), array(100e6));

        assertEq(strategy.deploymentCapOf(deployer), 100e6);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(deployer), array(100e6));
    }

    function test_setDeploymentCaps_revert_noChange_neverCappedZero() external {
        address whitelistedDeployer = makeAddr("whitelistedDeployer");
        address blacklistedDeployer = makeAddr("blacklistedDeployer");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", whitelistedDeployer, true);

        assertEq(strategy.deploymentCapOf(whitelistedDeployer), 0);
        assertEq(strategy.deploymentCapOf(blacklistedDeployer), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(whitelistedDeployer), array(uint256(0)));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SDC:NO_CHANGE");
        strategy.setDeploymentCaps(array(blacklistedDeployer), array(uint256(0)));
    }

}

contract SetDeploymentCapsSuccessTests is TestBase {

    address deployer1 = makeAddr("deployer1");
    address deployer2 = makeAddr("deployer2");
    address deployer3 = makeAddr("deployer3");

    function setUp() public override {
        super.setUp();

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer1, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer2, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", deployer3, true);
    }

    function test_setDeploymentCaps_success_singleAddress() external {
        uint256 cap = 100e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);
        assertEq(strategy.deploymentCapOf(deployer2), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, cap);

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
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, cap1);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer2, cap2);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer3, cap3);

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
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, cap1);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, cap2);

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
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, updatedCap);

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
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, updatedCap);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(updatedCap));

        assertEq(strategy.deploymentCapOf(deployer1), updatedCap);
    }

    function test_setDeploymentCaps_success_calledByOperationalAdmin() external {
        uint256 cap = 100e6;

        assertEq(strategy.deploymentCapOf(deployer1), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, cap);

        vm.prank(securityAdmin);
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
        emit IMapleAllocationStrategy.DeploymentCapSet(deployer1, 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(deployer1), array(uint256(0)));

        assertEq(strategy.deploymentCapOf(deployer1), 0);
    }

    function test_setDeploymentCaps_success_revokedDeployer_zeroCap() external {
        address revokedDeployer = makeAddr("revokedDeployer");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", revokedDeployer, true);

        uint256 cap = 100e6;

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(revokedDeployer), array(cap));

        assertEq(strategy.deploymentCapOf(revokedDeployer), cap);

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", revokedDeployer, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.DeploymentCapSet(revokedDeployer, 0);

        vm.prank(strategyDelegate);
        strategy.setDeploymentCaps(array(revokedDeployer), array(uint256(0)));

        assertEq(strategy.deploymentCapOf(revokedDeployer), 0);
    }

}
