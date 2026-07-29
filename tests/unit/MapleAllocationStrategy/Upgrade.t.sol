// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { MapleAllocationStrategy } from "../../../contracts/MapleAllocationStrategy.sol";

import { MockMigrator } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract UpgradeTests is TestBase {

    address migrator          = address(new MockMigrator());
    address newImplementation = address(new MapleAllocationStrategy());

    bytes arguments = abi.encode(address(1337));

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        strategyFactory.registerImplementation(200, newImplementation, initializer);
        strategyFactory.enableUpgradePath(100, 200, migrator);
        vm.stopPrank();
    }

    function test_upgrade_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAllocationStrategy.upgrade.selector, true);

        vm.prank(securityAdmin);
        vm.expectRevert("MAS:PAUSED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(securityAdmin);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAuthorized() external {
        vm.expectRevert("MAS:U:NOT_AUTHORIZED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAllowed() external {
        vm.prank(governor);
        strategyFactory.disableUpgradePath(100, 200);

        vm.prank(securityAdmin);
        vm.expectRevert("MPF:UI:NOT_ALLOWED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_invalidArguments() external {
        vm.prank(securityAdmin);
        vm.expectRevert("MPF:UI:FAILED");
        strategy.upgrade(200, "");
    }

    function test_upgrade_success() external {
        assertEq(strategy.strategyManager(), address(manager));

        vm.expectEmit();
        emit IMapleProxied.Upgraded(200, arguments);

        vm.prank(securityAdmin);
        strategy.upgrade(200, arguments);

        assertEq(strategy.strategyManager(), address(1337));
    }

}
