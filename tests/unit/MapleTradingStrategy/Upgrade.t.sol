// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { MockMigrator } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract UpgradeTests is TestBase {

    address migrator          = address(new MockMigrator());
    address newImplementation = address(new MapleTradingStrategy());

    bytes arguments = abi.encode(address(1337));

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        factory.registerImplementation(200, newImplementation, initializer);
        factory.enableUpgradePath(100, 200, migrator);
        vm.stopPrank();
    }

    function test_upgrade_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.upgrade.selector, true);

        vm.prank(securityAdmin);
        vm.expectRevert("MTS:PAUSED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(securityAdmin);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAuthorized() external {
        vm.expectRevert("MTS:U:NOT_AUTHORIZED");
        strategy.upgrade(200, arguments);
    }

    function test_upgrade_revert_notAllowed() external {
        vm.prank(governor);
        factory.disableUpgradePath(100, 200);

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
        assertEq(strategy.manager(), params.manager);

        vm.expectEmit();
        emit IMapleProxied.Upgraded(200, arguments);

        vm.prank(securityAdmin);
        strategy.upgrade(200, arguments);

        assertEq(strategy.manager(), address(1337));
    }

}
