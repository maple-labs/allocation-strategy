// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract FundUnderlyingStrategyTests is TestBase {

    uint256 assetsIn = 1_000e6;

    function test_fundUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.fundUnderlyingStrategy.selector, true);

        vm.prank(address(manager));
        vm.expectRevert("MTS:PAUSED");
        strategy.fundUnderlyingStrategy(assetsIn, "");
    }

    function test_fundUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MTS:NOT_STRATEGY_MANAGER");
        strategy.fundUnderlyingStrategy(assetsIn, "");
    }

    function test_fundUnderlyingStrategy_success() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyFunded(address(manager), assetsIn);

        vm.prank(address(manager));
        uint256 assetsOut = strategy.fundUnderlyingStrategy(assetsIn, "");

        assertEq(assetsOut, assetsIn);
    }

}
