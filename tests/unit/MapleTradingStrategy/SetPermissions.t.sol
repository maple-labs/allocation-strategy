// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetPermissionsFailureTests is TestBase {

    address tradingAddress1 = makeAddr("tradingAddress1");
    address tradingAddress2 = makeAddr("tradingAddress2");

    function test_setPermissions_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.setPermissions.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_zeroLength() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:ZERO_LENGTH");
        strategy.setPermissions(new address[](0), new bool[](0), new bool[](0), new bool[](0));
    }

    function test_setPermissions_revert_lengthMismatch() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](1), new bool[](2), new bool[](2));

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](2), new bool[](1), new bool[](2));

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:LENGTH_MISMATCH");
        strategy.setPermissions(new address[](2), new bool[](2), new bool[](2), new bool[](1));
    }

    function test_setPermissions_revert_invalidTradingAddress() external {
        address invalidTradingAddress = makeAddr("invalidTradingAddress");

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:NOT_TRADING_ADDRESS");
        strategy.setPermissions(
            array(invalidTradingAddress),
            array(true),
            array(true),
            array(true)
        );
    }

    function test_setPermissions_revert_invalidTradingAddress_batch() external {
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, true);
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress2, false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:NOT_TRADING_ADDRESS");
        strategy.setPermissions(
            array(tradingAddress1, tradingAddress2),
            array(true,            true),
            array(false,           false),
            array(false,           false)
        );
    }

    function test_setPermissions_revert_noChange_defaultFalse() external {
        address tradingAddress = makeAddr("tradingAddress");

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:NO_CHANGE");
        strategy.setPermissions(
            array(tradingAddress),
            array(false),
            array(false),
            array(false)
        );
    }

    function test_setPermissions_revert_noChange_existingPermissions() external {
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1),
            array(true),
            array(false),
            array(true)
        );

        assertPermissions(tradingAddress1, true, false, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SP:NO_CHANGE");
        strategy.setPermissions(
            array(tradingAddress1),
            array(true),
            array(false),
            array(true)
        );
    }

}

contract SetPermissionsSuccessTests is TestBase {

    address tradingAddress1 = makeAddr("tradingAddress1");
    address tradingAddress2 = makeAddr("tradingAddress2");
    address tradingAddress3 = makeAddr("tradingAddress3");

    function setUp() public override {
        super.setUp();

        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, true);
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress2, true);
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress3, true);
    }

    function test_setPermissions_success_singleAddress() external {
        assertPermissions(tradingAddress1, false, false, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, true, false, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1),
            array(true),
            array(false),
            array(true)
        );

        assertPermissions(tradingAddress1, true, false, true);
    }

    function test_setPermissions_success_multipleAddresses() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, true, false, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress2, false, true, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress3, false, false, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1, tradingAddress2, tradingAddress3),
            array(true,            false,           false),
            array(false,           true,            false),
            array(false,           false,           true)
        );

        assertPermissions(tradingAddress1, true,  false, false);
        assertPermissions(tradingAddress2, false, true,  false);
        assertPermissions(tradingAddress3, false, false, true);
    }

    function test_setPermissions_success_duplicateAddress() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, true, false, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, false, true, true);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1, tradingAddress1),
            array(true,            false),
            array(false,           true),
            array(false,           true)
        );

        assertPermissions(tradingAddress1, false, true, true);
    }

    function test_setPermissions_success_calledByOperationalAdmin() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, false, true, false);

        vm.prank(operationalAdmin);
        strategy.setPermissions(
            array(tradingAddress1),
            array(false),
            array(true),
            array(false)
        );

        assertPermissions(tradingAddress1, false, true, false);
    }

    function test_setPermissions_success_revokeAfterGlobalsApprovalRemoved() external {
        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1),
            array(true),
            array(true),
            array(true)
        );

        assertPermissions(tradingAddress1, true, true, true);

        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, false);

        vm.expectEmit();
        emit IMapleTradingStrategy.PermissionSet(tradingAddress1, false, false, false);

        vm.prank(strategyDelegate);
        strategy.setPermissions(
            array(tradingAddress1),
            array(false),
            array(false),
            array(false)
        );

        assertPermissions(tradingAddress1, false, false, false);
    }

}
