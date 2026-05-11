// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetImplementationTests is TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleTradingStrategy());
    }

    function test_setImplementation_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.setImplementation.selector, true);

        vm.expectRevert("MTS:PAUSED");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_revert_notFactory() external {
        vm.expectRevert("MTS:NOT_FACTORY");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategy.implementation(), implementation);

        vm.prank(address(factory));
        strategy.setImplementation(newImplementation);

        assertEq(strategy.implementation(), newImplementation);
    }

}
