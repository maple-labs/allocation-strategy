// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetPermissionsFailureTests is TestBase {

    address managedWallet1 = makeAddr("managedWallet1");
    address managedWallet2 = makeAddr("managedWallet2");

    function test_setPermissions_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAllocationStrategy.setPermissions.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:LOCKED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_notAuthorized() external {
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_notAuthorized_operationalAdmin() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_zeroLength() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:ZERO_LENGTH");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_lengthMismatch() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](1), new bool[](2), new bool[](2));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](2), new bool[](1), new bool[](2));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](2), new bool[](2), new bool[](1));
    }

    function test_setPermissions_revert_invalidManagedWallet() external {
        address invalidWallet = makeAddr("invalidWallet");

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:NOT_MAPLE_MANAGED_WALLET");
        strategy.setPermissions(array(invalidWallet), array(true), array(true), array(true));
    }

    function test_setPermissions_revert_invalidManagedWallet_batch() external {
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet1, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet2, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:NOT_MAPLE_MANAGED_WALLET");
        strategy.setPermissions(array(managedWallet1, managedWallet2), array(true, true), array(false, false), array(false, false));
    }

    function test_setPermissions_revert_noChange_defaultFalse() external {
        address managedWallet = makeAddr("managedWallet");

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:NO_CHANGE");
        strategy.setPermissions(array(managedWallet), array(false), array(false), array(false));
    }

    function test_setPermissions_revert_noChange_existingPermissions() external {
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet1, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(array(managedWallet1), array(true), array(false), array(true));

        assertPermissions(managedWallet1, true, false, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SP:NO_CHANGE");
        strategy.setPermissions(array(managedWallet1), array(true), array(false), array(true));
    }

}

contract SetPermissionsSuccessTests is TestBase {

    address managedWallet1 = makeAddr("managedWallet1");
    address managedWallet2 = makeAddr("managedWallet2");
    address managedWallet3 = makeAddr("managedWallet3");

    function setUp() public override {
        super.setUp();

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet1, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet2, true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet3, true);
    }

    function test_setPermissions_success_singleAddress() external {
        assertPermissions(managedWallet1, false, false, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, true, false, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(array(managedWallet1), array(true), array(false), array(true));

        assertPermissions(managedWallet1, true, false, true);
    }

    function test_setPermissions_success_multipleAddresses() external {
        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, true, false, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet2, false, true, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet3, false, false, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(managedWallet1, managedWallet2, managedWallet3),
            array(true, false, false),
            array(false, true, false),
            array(false, false, true)
        );

        assertPermissions(managedWallet1, true, false, false);
        assertPermissions(managedWallet2, false, true, false);
        assertPermissions(managedWallet3, false, false, true);
    }

    function test_setPermissions_success_duplicateAddress() external {
        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, true, false, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, false, true, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(array(managedWallet1, managedWallet1), array(true, false), array(false, true), array(false, true));

        assertPermissions(managedWallet1, false, true, true);
    }

    function test_setPermissions_success_calledBySecurityAdmin() external {
        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, false, true, false);

        vm.prank(securityAdmin);
        strategy.setPermissions(array(managedWallet1), array(false), array(true), array(false));

        assertPermissions(managedWallet1, false, true, false);
    }

    function test_setPermissions_success_revokeAfterGlobalsApprovalRemoved() external {
        vm.prank(strategyDelegate);
        strategy.setPermissions(array(managedWallet1), array(true), array(true), array(true));

        assertPermissions(managedWallet1, true, true, true);

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet1, false);

        vm.expectEmit();
        emit IMapleAllocationStrategy.PermissionSet(managedWallet1, false, false, false);

        vm.prank(strategyDelegate);
        strategy.setPermissions(array(managedWallet1), array(false), array(false), array(false));

        assertPermissions(managedWallet1, false, false, false);
    }

}
