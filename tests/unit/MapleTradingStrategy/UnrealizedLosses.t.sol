// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

// TODO: Add tests that include a combination of impairing and recognizing losses.
contract UnrealizedLossesTests is TestBase {

    uint256 partialAssets = 350_000e6;
    uint256 totalAssets   = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        strategy.__setDeployedAssetsOf(deployer, totalAssets);
    }

    function test_unrealizedLosses_noImpairment() external view {
        assertEq(strategy.unrealizedLosses(), 0);
    }

    function test_unrealizedLosses_partialImpairment() external {
        strategy.__setImpairedAssets(partialAssets);

        assertEq(strategy.unrealizedLosses(), partialAssets);
    }

    function test_unrealizedLosses_fullImpairment() external {
        strategy.__setImpairedAssets(totalAssets);

        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_unrealizedLosses_clampedImpairment() external {
        strategy.__setImpairedAssets(totalAssets + 1);

        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_unrealizedLosses_maximumImpairment() external {
        strategy.__setImpairedAssets(type(uint256).max);

        assertEq(strategy.unrealizedLosses(), totalAssets);
    }

    function test_unrealizedLosses_zeroAum() external {
        strategy.__setDeployedAssetsOf(deployer, 0);
        strategy.__setImpairedAssets(partialAssets);

        assertEq(strategy.unrealizedLosses(), 0);
    }

}
