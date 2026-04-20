// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple trading strategies.
 */
interface IMapleTradingStrategyInitializer {

    /**
     *  @dev   Parameters required to initialize a trading strategy.
     *  @param manager Address of the strategy manager contract.
     */
    struct Parameters {
        address manager;
    }

    /**
     *  @dev   Emitted when the trading strategy proxy is initialized.
     *  @param params Trading strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
