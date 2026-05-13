// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { MockMigrator } from "../../utils/Mocks.sol";
import { TestBase }     from "../../utils/TestBase.sol";

contract MigrateTests is TestBase {

    address migrator = address(new MockMigrator());

    bytes arguments = abi.encode(address(1337));

    function test_migrate_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.migrate.selector, true);

        vm.expectRevert("MTS:PAUSED");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_revert_notFactory() external {
        vm.expectRevert("MTS:NOT_FACTORY");
        strategy.migrate(migrator, arguments);
    }

    function test_migrate_revert_invalidMigrator() external {
        vm.prank(address(strategyFactory));
        vm.expectRevert("MTS:M:FAILED");
        strategy.migrate(makeAddr("randomAddress"), arguments);
    }

    function test_migrate_revert_invalidArguments() external {
        vm.prank(address(strategyFactory));
        vm.expectRevert("MTS:M:FAILED");
        strategy.migrate(migrator, "");
    }

    function test_migrate_success() external {
        assertEq(strategy.strategyManager(), address(manager));

        vm.prank(address(strategyFactory));
        strategy.migrate(migrator, arguments);

        assertEq(strategy.strategyManager(), address(1337));
    }

}
