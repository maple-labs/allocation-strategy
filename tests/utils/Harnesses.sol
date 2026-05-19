// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleTradingStrategy }            from "../../contracts/MapleTradingStrategy.sol";
import { MapleTradingStrategyInitializer } from "../../contracts/MapleTradingStrategyInitializer.sol";

contract MapleTradingStrategyHarness is MapleTradingStrategy {

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}

contract MapleTradingStrategyInitializerHarness is MapleTradingStrategyInitializer {

    function __initialize(Parameters memory params_) external {
        _initialize(params_);
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}
