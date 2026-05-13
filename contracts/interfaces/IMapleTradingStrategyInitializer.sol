// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines a contract used to initialize new Maple trading strategies.
 */
interface IMapleTradingStrategyInitializer {

    /**
     *  @dev   Parameters required to initialize a trading strategy.
     *  @param fundsAsset              Address of the asset used by the strategy.
     *  @param strategyManager         Address of the strategy manager contract.
     *  @param strategyMetadata        Optional metadata associated with the trading strategy.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
     */
    struct Parameters {
        address fundsAsset;
        address strategyManager;
        string  strategyMetadata;
        uint32  strategyDelegateFeeRate;
        uint32  strategyProtocolFeeRate;
    }

    /**
     *  @dev   Emitted when the trading strategy proxy is initialized.
     *  @param params Trading strategy parameters set during initialization.
     */
    event Initialized(Parameters params);

}
