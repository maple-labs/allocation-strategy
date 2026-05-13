// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple trading strategy.
 */
interface IMapleTradingStrategyStorage {

    /**************************************************************************************************************************************/
    /*** Addresses                                                                                                                      ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the address of the asset used by the strategy.
     *          Must be ERC-20 compatible.
     *  @return fundsAsset Address of the asset used by the strategy.
     */
    function fundsAsset() external view returns (address fundsAsset);

    /**
     *  @dev    Returns the address of the strategy manager contract.
     *  @return strategyManager Address of the strategy manager.
     */
    function strategyManager() external view returns (address strategyManager);

    /**************************************************************************************************************************************/
    /*** Fees                                                                                                                           ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the percentage of all strategy yield collected by the strategy delegate.
     *          Defined with 6 decimals of precision (1e6 == 100%).
     *  @return strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
     */
    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    /**
     *  @dev    Returns the percentage of all strategy yield collected by the Maple treasury.
     *          Defined with 6 decimals of precision (1e6 == 100%).
     *  @return strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
     */
    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

    /**************************************************************************************************************************************/
    /*** Miscellaneous                                                                                                                  ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns arbitrary metadata associated with this instance of the trading strategy.
     *  @return strategyMetadata Optional metadata associated with the strategy.
     */
    function strategyMetadata() external view returns (string memory strategyMetadata);

}
