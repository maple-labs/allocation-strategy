// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetMetadataFailureTests is TestBase {

    function test_setMetadata_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.setMetadata.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.setMetadata("abc");
    }

    function test_setMetadata_revert_noChange() external {
        string memory metadata = strategy.strategyMetadata();

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SM:NO_CHANGE");
        strategy.setMetadata(metadata);
    }

}

contract SetMetadataSuccessTests is TestBase {

    function test_setMetadata_success_emptyString() external {
        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyMetadataSet("");

        vm.prank(strategyDelegate);
        strategy.setMetadata("");

        assertEq(strategy.strategyMetadata(), "");
    }

    function test_setMetadata_success_operationalAdmin() external {
        string memory metadata = "abc";

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyMetadataSet(metadata);

        vm.prank(operationalAdmin);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);
    }

    function test_setMetadata_success_strategyDelegate() external {
        string memory metadata = "abc";

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyMetadataSet(metadata);

        vm.prank(strategyDelegate);
        strategy.setMetadata(metadata);

        assertEq(strategy.strategyMetadata(), metadata);
    }

}
