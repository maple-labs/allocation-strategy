// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract ImpairTestBase is TestBase {

    uint256 partialAssets = 345_214e6;
    uint256 totalAssets   = 1_250_000e6;

    function setUp() public virtual override {
        super.setUp();

        strategy.__setDeployedAssetsOf(deployer, totalAssets);
    }

}

contract ImpairFailureTests is ImpairTestBase {

    function test_impair_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.impair.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.impair(partialAssets);
    }

    function test_impair_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.impair(partialAssets);
    }

    function test_impair_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.impair(partialAssets);
    }

    function test_impair_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:I:ZERO_ASSETS");
        strategy.impair(0);
    }

}

contract ImpairSuccessTests is ImpairTestBase {

    function test_impair_success_partial() external {
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(partialAssets);

        vm.prank(strategyDelegate);
        strategy.impair(partialAssets);

        assertEq(strategy.impairedAssets(),   partialAssets);
        assertEq(strategy.unrealizedLosses(), partialAssets);
    }

    function test_impair_success_total() external {
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(totalAssets);

        vm.prank(operationalAdmin);
        strategy.impair(totalAssets);

        assertEq(strategy.impairedAssets(),   totalAssets);
        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_impair_success_clamped() external {
        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);

        vm.prank(strategyDelegate);
        strategy.impair(totalAssets + 1);

        assertEq(strategy.impairedAssets(),   totalAssets + 1);
        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_impair_success_accumulated() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(partialAssets);

        vm.prank(operationalAdmin);
        strategy.impair(partialAssets);

        assertEq(strategy.impairedAssets(),   partialAssets);
        assertEq(strategy.unrealizedLosses(), partialAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(partialAssets);

        vm.prank(strategyDelegate);
        strategy.impair(partialAssets);

        assertEq(strategy.impairedAssets(),   2 * partialAssets);
        assertEq(strategy.unrealizedLosses(), 2 * partialAssets);
    }

    function test_impair_success_noEffect() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(totalAssets);

        vm.prank(operationalAdmin);
        strategy.impair(totalAssets);

        assertEq(strategy.impairedAssets(),   totalAssets);
        assertEq(strategy.unrealizedLosses(), totalAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.Impaired(1);

        vm.prank(strategyDelegate);
        strategy.impair(1);

        assertEq(strategy.impairedAssets(),   totalAssets + 1);
        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

}
