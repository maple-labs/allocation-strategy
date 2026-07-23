// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";
import { MapleTradingStrategy }  from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RecognizeLossTestBase is TestBase {

    address managedWallet1 = makeAddr("managedWallet1");
    address managedWallet2 = makeAddr("managedWallet2");

    uint256 deployedAssets1 = 1_250_000e6;
    uint256 deployedAssets2 = 600_000e6;
    uint256 impairedAssets  = 900_333e6;

    uint256 partialLoss = 165_000e6;

    function setUp() public virtual override {
        super.setUp();

        strategy.__setDeployedAssetsOf(managedWallet1, deployedAssets1);
        strategy.__setDeployedAssetsOf(managedWallet2, deployedAssets2);
    }

}

contract RecognizeLossFailureTests is RecognizeLossTestBase {

    function test_recognizeLoss_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.recognizeLoss.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.recognizeLoss(deployedAssets1, managedWallet1);
    }

    function test_recognizeLoss_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.recognizeLoss(deployedAssets1, managedWallet1);
    }

    function test_recognizeLoss_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.recognizeLoss(deployedAssets1, managedWallet1);
    }

    function test_recognizeLoss_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RL:ZERO_ASSETS");
        strategy.recognizeLoss(0, managedWallet1);
    }

    function test_recognizeLoss_revert_nothingDeployed() external {
        strategy.__setDeployedAssetsOf(managedWallet1, 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RL:EXCEEDS_DEPLOYED");
        strategy.recognizeLoss(1, managedWallet1);
    }

    function test_recognizeLoss_revert_exceedsDeployed() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:RL:EXCEEDS_DEPLOYED");
        strategy.recognizeLoss(deployedAssets1 + 1, managedWallet1);
    }

}

contract RecognizeLossSuccessTests is RecognizeLossTestBase {

    function test_recognizeLoss_partialLoss_strategyDelegate() external {
        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet1, partialLoss);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(partialLoss, managedWallet1);

        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1 - partialLoss);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2 - partialLoss);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2 - partialLoss);
    }

    function test_recognizeLoss_partialLoss_operationalAdmin() external {
        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(operationalAdmin, managedWallet1, partialLoss);

        vm.prank(operationalAdmin);
        strategy.recognizeLoss(partialLoss, managedWallet1);

        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1 - partialLoss);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2 - partialLoss);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2 - partialLoss);
    }

    function test_recognizeLoss_totalLoss() external {
        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet1, deployedAssets1);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(deployedAssets1, managedWallet1);

        assertEq(strategy.deployedAssetsOf(managedWallet1), 0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets2);
    }

    function test_recognizeLoss_withImpairment() external {
        strategy.__setImpairedAssets(impairedAssets);

        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet2, deployedAssets2);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(deployedAssets2, managedWallet2);

        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), 0);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);
    }

    function test_recognizeLoss_clampedImpairment() external {
        strategy.__setImpairedAssets(impairedAssets);

        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), impairedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet1, deployedAssets1);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(deployedAssets1, managedWallet1);

        assertEq(strategy.deployedAssetsOf(managedWallet1), 0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets2);

        assertEq(strategy.impairedAssets(),   impairedAssets);
        assertEq(strategy.unrealizedLosses(), deployedAssets2);
    }

    function test_recognizeLoss_multipleLosses() external {
        assertEq(strategy.deployedAssetsOf(managedWallet1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets1 + deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets1 + deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet1, deployedAssets1);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(deployedAssets1, managedWallet1);

        assertEq(strategy.deployedAssetsOf(managedWallet1), 0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets2);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet2, partialLoss);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(partialLoss, managedWallet2);

        assertEq(strategy.deployedAssetsOf(managedWallet1), 0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2 - partialLoss);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets2 - partialLoss);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets2 - partialLoss);

        vm.expectEmit();
        emit IMapleTradingStrategy.LossRecognized(strategyDelegate, managedWallet2, partialLoss);

        vm.prank(strategyDelegate);
        strategy.recognizeLoss(partialLoss, managedWallet2);

        assertEq(strategy.deployedAssetsOf(managedWallet1), 0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), deployedAssets2 - 2 * partialLoss);
        assertEq(strategy.totalDeployedAssets(),            deployedAssets2 - 2 * partialLoss);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets2 - 2 * partialLoss);
    }

}
