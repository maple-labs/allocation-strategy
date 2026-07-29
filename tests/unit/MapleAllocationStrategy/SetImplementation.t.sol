// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAllocationStrategy } from "../../../contracts/MapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetImplementationTests is TestBase {

    address internal newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new MapleAllocationStrategy());
    }

    function test_setImplementation_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAllocationStrategy.setImplementation.selector, true);

        vm.expectRevert("MAS:PAUSED");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_revert_notFactory() external {
        vm.expectRevert("MAS:NOT_FACTORY");
        strategy.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(strategy.implementation(), implementation);

        vm.prank(address(strategyFactory));
        strategy.setImplementation(newImplementation);

        assertEq(strategy.implementation(), newImplementation);
    }

}
