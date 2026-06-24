// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RemoveImpairmentTestBase is TestBase {

    uint256 assetsToUnimpair = 10_000e6;
    uint256 impairedAssets   = 150_000e6;
    uint256 totalAssets      = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        strategy.__setDeployedAssetsOf(deployer, totalAssets);
        strategy.__setImpairedAssets(impairedAssets);
    }

}

contract RemoveImpairmentFailureTests is RemoveImpairmentTestBase {

    function test_removeImpairment_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.removeImpairment.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.removeImpairment(assetsToUnimpair);
    }

    function test_removeImpairment_revert_notAuthorized() external {
        vm.prank(governor);
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.removeImpairment(assetsToUnimpair);
    }

    function test_removeImpairment_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RI:ZERO_ASSETS");
        strategy.removeImpairment(0);
    }

    function test_removeImpairment_revert_nothingImpaired() external {
        strategy.__setImpairedAssets(0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RI:EXCEEDS_IMPAIRMENT");
        strategy.removeImpairment(1);
    }

    function test_removeImpairment_revert_exceedsImpairment() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RI:EXCEEDS_IMPAIRMENT");
        strategy.removeImpairment(impairedAssets + 1);
    }

}

contract RemoveImpairmentSuccessTests is RemoveImpairmentTestBase {

    function test_removeImpairment_success_partial() external {
        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(assetsToUnimpair);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   impairedAssets - assetsToUnimpair);
        assertEq(strategy.unrealizedLosses(), impairedAssets - assetsToUnimpair);
    }

    function test_removeImpairment_success_full() external {
        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(impairedAssets);

        vm.prank(operationalAdmin);
        strategy.removeImpairment(impairedAssets);

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);
    }

    function test_removeImpairment_success_multiple() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(assetsToUnimpair);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   impairedAssets - assetsToUnimpair);
        assertEq(strategy.unrealizedLosses(), impairedAssets - assetsToUnimpair);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(assetsToUnimpair);

        vm.prank(operationalAdmin);
        strategy.removeImpairment(assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   impairedAssets - 2 * assetsToUnimpair);
        assertEq(strategy.unrealizedLosses(), impairedAssets - 2 * assetsToUnimpair);
    }

    function test_removeImpairment_success_noEffect() external {
        strategy.__setImpairedAssets(totalAssets + assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   totalAssets + assetsToUnimpair);
        assertEq(strategy.unrealizedLosses(), totalAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(assetsToUnimpair);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   totalAssets);
        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_removeImpairment_success_overimpairment() external {
        strategy.__setImpairedAssets(totalAssets + assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   totalAssets + assetsToUnimpair);
        assertEq(strategy.unrealizedLosses(), totalAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(totalAssets + assetsToUnimpair);

        vm.prank(strategyDelegate);
        strategy.removeImpairment(totalAssets + assetsToUnimpair);

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);
    }

}
