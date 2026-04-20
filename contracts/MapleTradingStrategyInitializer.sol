// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleTradingStrategyInitializer } from "./interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyStorage } from "./MapleTradingStrategyStorage.sol";

contract MapleTradingStrategyInitializer is IMapleTradingStrategyInitializer, MapleTradingStrategyStorage {

    function _initialize(IMapleTradingStrategyInitializer.Parameters memory params_) internal {
        manager = params_.manager;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
