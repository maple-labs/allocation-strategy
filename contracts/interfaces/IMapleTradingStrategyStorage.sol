// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @title Defines the storage layout of a Maple trading strategy.
 */
interface IMapleTradingStrategyStorage {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Defines which asset management functions an address is authorized to call.
     *  @param canDeployAssets True if the address can call deployAssets().
     *  @param canReturnAssets True if the address can call returnAssets().
     *  @param canRealizeYield True if the address can call realizeYield().
     */
    struct Permissions {
        bool canDeployAssets;
        bool canReturnAssets;
        bool canRealizeYield;
    }

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
    /*** Caps                                                                                                                           ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the amount of assets currently deployed by a trading address.
     *  @param  account        Address of the trading address.
     *  @return deployedAssets Amount of assets currently deployed by the address.
     */
    function deployedAssetsOf(address account) external view returns (uint256 deployedAssets);

    /**
     *  @dev    Returns the deployment cap configured for a trading address.
     *  @param  account       Address of the trading address to read the cap for.
     *  @return deploymentCap Maximum amount of assets the trading address can deploy.
     */
    function deploymentCapOf(address account) external view returns (uint256 deploymentCap);

    /**************************************************************************************************************************************/
    /*** Accounting                                                                                                                     ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the total amount of assets in the yield buffer since it was last updated.
     *  @return scheduledYieldAssets Total assets in the yield buffer since last update.
     */
    function scheduledYieldAssets() external view returns (uint256 scheduledYieldAssets);

    /**
     *  @dev    Returns the total amount of assets currently deployed across all trading addresses.
     *  @return totalDeployedAssets Total amount of assets currently deployed by the strategy.
     */
    function totalDeployedAssets() external view returns (uint256 totalDeployedAssets);

    /**
     *  @dev    Returns the timestamp when all yield assets are fully realized.
     *  @return yieldDeadline Timestamp when yield assets are fully realized.
     */
    function yieldDeadline() external view returns (uint32 yieldDeadline);

    /**
     *  @dev    Returns the timestamp when the yield buffer was last updated.
     *  @return yieldStart Timestamp when the current yield buffer was last updated.
     */
    function yieldStart() external view returns (uint32 yieldStart);

    /**************************************************************************************************************************************/
    /*** Permissions                                                                                                                    ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the permission flags for a given address.
     *  @param  account         Address to read permissions for.
     *  @return canDeployAssets Defines if an address can deploy assets.
     *  @return canReturnAssets Defines if an address can return assets.
     *  @return canRealizeYield Defines if an address can realize yield.
     */
    function permissions(address account)
        external view returns (
            bool canDeployAssets,
            bool canReturnAssets,
            bool canRealizeYield
        );

    /**************************************************************************************************************************************/
    /*** Miscellaneous                                                                                                                  ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns arbitrary metadata associated with this instance of the trading strategy.
     *  @return strategyMetadata Optional metadata associated with the strategy.
     */
    function strategyMetadata() external view returns (string memory strategyMetadata);

}
