// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleTradingStrategy }            from "../../contracts/MapleTradingStrategy.sol";
import { MapleTradingStrategyInitializer } from "../../contracts/MapleTradingStrategyInitializer.sol";

contract MapleTradingStrategyHarness is MapleTradingStrategy {}

contract MapleTradingStrategyInitializerHarness is MapleTradingStrategyInitializer {

    function __initialize(Parameters memory params_) external {
        _initialize(params_);
    }

}
