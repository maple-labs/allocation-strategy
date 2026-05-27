// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract ReturnAssetsTestBase is TestBase {

    address tradingAddress1 = makeAddr("tradingAddress");
    address tradingAddress2 = makeAddr("tradingAddress2");

    uint256 deployedAssets1 = 1_249_500e6;
    uint256 deployedAssets2 = 1_785_666.33e6;

    function setUp() public override {
        super.setUp();

        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, true);
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress2, true);

        strategy.__setPermissions(tradingAddress1, true);
        strategy.__setPermissions(tradingAddress2, true);

        strategy.__setDeployedAssetsOf(tradingAddress1, deployedAssets1);
        strategy.__setDeployedAssetsOf(tradingAddress2, deployedAssets2);

        asset.mint(tradingAddress1, deployedAssets1);
        asset.mint(tradingAddress2, deployedAssets2);

        vm.prank(tradingAddress1);
        asset.approve(address(strategy), type(uint256).max);

        vm.prank(tradingAddress2);
        asset.approve(address(strategy), type(uint256).max);
    }

}

contract ReturnAssetsFailureTests is ReturnAssetsTestBase {

    function test_returnAssets_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.returnAssets.selector, true);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:PAUSED");
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");
    }

    function test_returnAssets_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:LOCKED");
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");
    }

    function test_returnAssets_revert_notTradingAddress() external {
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, false);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:NOT_TRADING_ADDRESS");
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");
    }

    function test_returnAssets_revert_notAllowed() external {
        strategy.__setPermissions(tradingAddress1, false);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:NOT_ALLOWED");
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");
    }

    function test_returnAssets_revert_zeroAssets() external {
        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:ZERO_ASSETS");
        strategy.returnAssets(0, tradingAddress1, "");
    }

    function test_returnAssets_revert_exceedsAssets_nothingDeployed() external {
        strategy.__setDeployedAssetsOf(tradingAddress1, 0);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:EXCEEDS_ASSETS");
        strategy.returnAssets(1, tradingAddress1, "");
    }

    function test_returnAssets_revert_exceedsAssets_exceedsDeployedAmount() external {
        strategy.__setDeployedAssetsOf(tradingAddress1, deployedAssets1);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:EXCEEDS_ASSETS");
        strategy.returnAssets(deployedAssets1 + 1, tradingAddress1, "");
    }

    function test_returnAssets_revert_transferFromFailed() external {
        asset.__setTransferFromReverts(true);

        vm.prank(tradingAddress1);
        vm.expectRevert("MTS:RA:TRANSFER_FAILED");
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");
    }

}

contract ReturnAssetsSuccessTests is ReturnAssetsTestBase {

    function test_returnAssets_success_partialReturn_sameDeployer() external {
        uint256 assetsToReturn = deployedAssets1 / 3;

        assertEq(asset.balanceOf(address(strategy)),  0);
        assertEq(asset.balanceOf(tradingAddress1),    deployedAssets1);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress1, tradingAddress1, assetsToReturn, "");

        vm.prank(tradingAddress1);
        strategy.returnAssets(assetsToReturn, tradingAddress1, "");

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1 - assetsToReturn);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2 - assetsToReturn);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn);
    }

    function test_returnAssets_success_fullReturn_sameDeployer() external {
        assertEq(asset.balanceOf(address(strategy)),  0);
        assertEq(asset.balanceOf(tradingAddress1),    deployedAssets1);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress1, tradingAddress1, deployedAssets1, "");

        vm.prank(tradingAddress1);
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");

        assertEq(asset.balanceOf(address(strategy)),  deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress1),    0);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), 0);
    }

    function test_returnAssets_success_partialReturn_differentDeployer() external {
        uint256 assetsToReturn = deployedAssets1 / 3;

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress2, tradingAddress1, assetsToReturn, "");

        vm.prank(tradingAddress2);
        strategy.returnAssets(assetsToReturn, tradingAddress1, "");

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - assetsToReturn);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2 - assetsToReturn);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);
    }

    function test_returnAssets_success_fullReturn_differentDeployer() external {
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress2, tradingAddress1, deployedAssets1, "");

        vm.prank(tradingAddress2);
        strategy.returnAssets(deployedAssets1, tradingAddress1, "");

        assertEq(asset.balanceOf(address(strategy)), deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - deployedAssets1);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), 0);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);
    }

    function test_returnAssets_success_partialReturn_revokedDeployer() external {
        uint256 assetsToReturn = deployedAssets1 / 4;

        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress1, false);
        strategy.__setPermissions(tradingAddress1, false);

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress2, tradingAddress1, assetsToReturn, "recovery");

        vm.prank(tradingAddress2);
        strategy.returnAssets(assetsToReturn, tradingAddress1, "recovery");

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - assetsToReturn);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2 - assetsToReturn);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);
    }

    function test_returnAssets_success_multipleCallersAndDeployers() external {
        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2);

        assertEq(strategy.totalDeployedAssets(),             deployedAssets1 + deployedAssets2);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        uint256 totalDeployedAssets = deployedAssets1 + deployedAssets2;

        /**********************************************************************************************************************************/
        /*** Step 1: Address 1 Returns Assets for Itself                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 assetsToReturn1 = deployedAssets1 / 7;

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress1, tradingAddress1, assetsToReturn1, "a");

        vm.prank(tradingAddress1);
        strategy.returnAssets(assetsToReturn1, tradingAddress1, "a");

        totalDeployedAssets -= assetsToReturn1;

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn1);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1 - assetsToReturn1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2);

        assertEq(strategy.totalDeployedAssets(),             totalDeployedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn1);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        /**********************************************************************************************************************************/
        /*** Step 2: Address 2 Returns Assets on Behalf of Address 1                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 assetsToReturn2 = deployedAssets1 / 13;

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress2, tradingAddress1, assetsToReturn2, "b");

        vm.prank(tradingAddress2);
        strategy.returnAssets(assetsToReturn2, tradingAddress1, "b");

        totalDeployedAssets -= assetsToReturn2;

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn1 + assetsToReturn2);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1 - assetsToReturn1);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - assetsToReturn2);

        assertEq(strategy.totalDeployedAssets(),             totalDeployedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn1 - assetsToReturn2);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2);

        /**********************************************************************************************************************************/
        /*** Step 3: Address 1 Returns Assets on Behalf of Address 2                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 assetsToReturn3 = deployedAssets2 / 9;

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress1, tradingAddress2, assetsToReturn3, "c");

        vm.prank(tradingAddress1);
        strategy.returnAssets(assetsToReturn3, tradingAddress2, "c");

        totalDeployedAssets -= assetsToReturn3;

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn1 + assetsToReturn2 + assetsToReturn3);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1 - assetsToReturn1 - assetsToReturn3);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - assetsToReturn2);

        assertEq(strategy.totalDeployedAssets(),             totalDeployedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn1 - assetsToReturn2);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2 - assetsToReturn3);

        /**********************************************************************************************************************************/
        /*** Step 4: Address 2 Returns Assets for Itself                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 assetsToReturn4 = deployedAssets2 / 17;

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsReturned(tradingAddress2, tradingAddress2, assetsToReturn4, "d");

        vm.prank(tradingAddress2);
        strategy.returnAssets(assetsToReturn4, tradingAddress2, "d");

        totalDeployedAssets -= assetsToReturn4;

        assertEq(asset.balanceOf(address(strategy)), assetsToReturn1 + assetsToReturn2 + assetsToReturn3 + assetsToReturn4);
        assertEq(asset.balanceOf(tradingAddress1),   deployedAssets1 - assetsToReturn1 - assetsToReturn3);
        assertEq(asset.balanceOf(tradingAddress2),   deployedAssets2 - assetsToReturn2 - assetsToReturn4);

        assertEq(strategy.totalDeployedAssets(),             totalDeployedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress1), deployedAssets1 - assetsToReturn1 - assetsToReturn2);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), deployedAssets2 - assetsToReturn3 - assetsToReturn4);
    }

}
