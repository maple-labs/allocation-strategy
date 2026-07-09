// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RecognizeLossAndRemoveImpairmentTestBase is TestBase {

    address tradingAddress1 = makeAddr("tradingAddress1");

    uint256 deployedAssets = 1_250_000e6;
    uint256 impairedAssets = 900_333e6;

    uint256 partialLoss     = 165_000e6;
    uint256 partialUnimpair = 50_000e6;

    function setUp() public virtual override {
        super.setUp();

        strategy.__setDeployedAssetsOf(tradingAddress1, deployedAssets);
        strategy.__setImpairedAssets(impairedAssets);
    }

}

contract RecognizeLossAndRemoveImpairmentFailureTests is RecognizeLossAndRemoveImpairmentTestBase {

    function test_recognizeLossAndRemoveImpairment_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.recognizeLossAndRemoveImpairment.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.recognizeLossAndRemoveImpairment(partialLoss, partialUnimpair, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.recognizeLossAndRemoveImpairment(partialLoss, partialUnimpair, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.recognizeLossAndRemoveImpairment(partialLoss, partialUnimpair, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_zeroAssetsLost() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RL:ZERO_ASSETS");
        strategy.recognizeLossAndRemoveImpairment(0, partialUnimpair, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsDeployed() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RL:EXCEEDS_DEPLOYED");
        strategy.recognizeLossAndRemoveImpairment(deployedAssets + 1, partialUnimpair, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_zeroAssetsUnimpaired() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RI:ZERO_ASSETS");
        strategy.recognizeLossAndRemoveImpairment(partialLoss, 0, tradingAddress1);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsImpairment() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RI:EXCEEDS_IMPAIRMENT");
        strategy.recognizeLossAndRemoveImpairment(partialLoss, impairedAssets + 1, tradingAddress1);
    }

}

contract RecognizeLossAndRemoveImpairmentSuccessTests is RecognizeLossAndRemoveImpairmentTestBase {

    function test_recognizeLossAndRemoveImpairment_success_partial_strategyDelegate() external {
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, tradingAddress1, partialLoss);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(partialUnimpair);

        vm.prank(strategyDelegate);
        strategy.recognizeLossAndRemoveImpairment(partialLoss, partialUnimpair, tradingAddress1);

        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets - partialLoss);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets - partialLoss);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets - partialLoss);

        assertEq(strategy.impairedAssets(),   impairedAssets - partialUnimpair);
        assertEq(strategy.unrealizedLosses(), impairedAssets - partialUnimpair);
    }

    function test_recognizeLossAndRemoveImpairment_success_partial_operationalAdmin() external {
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(operationalAdmin, tradingAddress1, partialLoss);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(partialUnimpair);

        vm.prank(operationalAdmin);
        strategy.recognizeLossAndRemoveImpairment(partialLoss, partialUnimpair, tradingAddress1);

        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets - partialLoss);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets - partialLoss);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets - partialLoss);

        assertEq(strategy.impairedAssets(),   impairedAssets - partialUnimpair);
        assertEq(strategy.unrealizedLosses(), impairedAssets - partialUnimpair);
    }

    function test_recognizeLossAndRemoveImpairment_success_total() external {
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, tradingAddress1, deployedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(impairedAssets);

        vm.prank(strategyDelegate);
        strategy.recognizeLossAndRemoveImpairment(deployedAssets, impairedAssets, tradingAddress1);

        assertEq(strategy.deployedAssetsOf(tradingAddress1), 0);
        assertEq(strategy.totalDeployedAssets(),             0);
        assertEq(strategy.assetsUnderManagement(),           0);

        assertEq(strategy.impairedAssets(),   0);
        assertEq(strategy.unrealizedLosses(), 0);
    }

    function test_recognizeLossAndRemoveImpairment_success_clampedImpairment() external {
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets);
        assertEq(strategy.totalDeployedAssets(),             deployedAssets);
        assertEq(strategy.assetsUnderManagement(),           deployedAssets);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, tradingAddress1, deployedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.ImpairmentRemoved(partialUnimpair);

        vm.prank(strategyDelegate);
        strategy.recognizeLossAndRemoveImpairment(deployedAssets, partialUnimpair, tradingAddress1);

        assertEq(strategy.deployedAssetsOf(tradingAddress1), 0);
        assertEq(strategy.totalDeployedAssets(),             0);
        assertEq(strategy.assetsUnderManagement(),           0);

        assertEq(strategy.impairedAssets(),   impairedAssets - partialUnimpair);
        assertEq(strategy.unrealizedLosses(), 0);
    }

}
