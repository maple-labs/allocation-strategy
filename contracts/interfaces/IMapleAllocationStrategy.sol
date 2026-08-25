// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleAllocationStrategyStorage } from "./IMapleAllocationStrategyStorage.sol";

/**
 *  @title Defines a Maple allocation strategy.
 */
interface IMapleAllocationStrategy is IMapleAllocationStrategyStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when assets are deployed.
     *  @param deployer       Address that deployed the assets.
     *  @param assets         Amount of assets deployed.
     *  @param recordedAssets Amount of assets recorded as held by the strategy after the deployment.
     *  @param metadata       Optional metadata associated with the deployment.
     */
    event AssetsDeployed(address indexed deployer, uint256 assets, uint256 recordedAssets, bytes metadata);

    /**
     *  @dev   Emitted when deployed assets are returned to the strategy.
     *  @param caller         Address that transferred the assets back.
     *  @param onBehalfOf     Address to which the returned assets were credited.
     *  @param assets         Amount of assets returned.
     *  @param recordedAssets Amount of assets recorded as held by the strategy after the return.
     *  @param metadata       Optional metadata associated with the repayment.
     */
    event AssetsReturned(address indexed caller, address indexed onBehalfOf, uint256 assets, uint256 recordedAssets, bytes metadata);

    /**
     *  @dev   Emitted when unrecorded assets are skimmed from the strategy.
     *  @param recipient Address that received the skimmed assets.
     *  @param assets    Amount of assets skimmed.
     */
    event AssetsSkimmed(address indexed recipient, uint256 assets);

    /**
     *  @dev   Emitted when the deployment cap of a managed wallet is set.
     *  @param account       Managed wallet the cap was set for.
     *  @param deploymentCap New deployment cap for the managed wallet.
     */
    event DeploymentCapSet(address indexed account, uint256 deploymentCap);

    /**
     *  @dev   Emitted when assets are impaired.
     *  @param assets Amount of assets that were impaired.
     */
    event Impaired(uint256 assets);

    /**
     *  @dev   Emitted when assets are unimpaired.
     *  @param assets Amount of assets that were unimpaired.
     */
    event ImpairmentRemoved(uint256 assets);

    /**
     *  @dev   Emitted when a loss is recognized against a deployer.
     *  @param caller   Address that called recognizeLoss.
     *  @param deployer Address of the deployer the loss is attributed to.
     *  @param assets   Amount of assets recognized as lost.
     */
    event LossRecognized(address indexed caller, address indexed deployer, uint256 assets);

    /**
     *  @dev   Emitted when permissions are set for a managed wallet.
     *  @param account         Managed wallet the permissions were set for.
     *  @param canDeployAssets Defines if the address can call deployAssets().
     *  @param canReturnAssets Defines if the address can call returnAssets().
     *  @param canRealizeYield Defines if the address can call realizeYield().
     */
    event PermissionSet(
        address indexed account,
        bool    canDeployAssets,
        bool    canReturnAssets,
        bool    canRealizeYield
    );

    /**
     *  @dev   Emitted when the strategy delegate fee rate is set.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    event StrategyDelegateFeeRateSet(uint32 strategyDelegateFeeRate);

    /**
     *  @dev   Emitted when assets are deployed into the allocation strategy.
     *  @param strategyManager Address of the associated strategy manager.
     *  @param assets          Amount of assets transferred into the allocation strategy.
     *  @param recordedAssets  Amount of assets recorded as held by the strategy after the funding.
     */
    event StrategyFunded(address indexed strategyManager, uint256 assets, uint256 recordedAssets);

    /**
     *  @dev   Emitted when the strategy metadata is set.
     *  @param strategyMetadata Optional metadata associated with the strategy.
     */
    event StrategyMetadataSet(string strategyMetadata);

    /**
     *  @dev   Emitted when the strategy protocol fee rate is set.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    event StrategyProtocolFeeRateSet(uint32 strategyProtocolFeeRate);

    /**
     *  @dev   Emitted when assets are withdrawn from the allocation strategy.
     *  @param strategyManager Address of the associated strategy manager.
     *  @param destination     Address that received the withdrawn assets.
     *  @param assets          Amount of assets withdrawn from the allocation strategy.
     *  @param recordedAssets  Amount of assets recorded as held by the strategy after the withdrawal.
     */
    event StrategyWithdrawn(address indexed strategyManager, address indexed destination, uint256 assets, uint256 recordedAssets);

    /**
     *  @dev   Emitted when unrealized yield is cancelled from the yield buffer.
     *  @param caller         Address that cancelled the yield.
     *  @param recipient      Address that received the cancelled yield.
     *  @param assets         Amount of unrealized yield cancelled.
     *  @param recordedAssets Amount of assets recorded as held by the strategy after the cancellation.
     */
    event YieldCancelled(address indexed caller, address indexed recipient, uint256 assets, uint256 recordedAssets);

    /**
     *  @dev   Emitted when the yield cap is set.
     *  @param yieldCap Maximum amount of assets that can be realized as yield in a single call.
     */
    event YieldCapSet(uint256 yieldCap);

    /**
     *  @dev   Emitted when yield is transferred to the yield buffer.
     *  @param caller          Address that transferred the yield.
     *  @param unrealizedYield Amount of unrealized yield carried over.
     *  @param netYield        Amount of net yield transferred.
     *  @param delegateFee     Amount of fees collected by the delegate.
     *  @param protocolFee     Amount of fees collected by the protocol.
     *  @param recordedAssets  Amount of assets recorded as held by the strategy after the realization.
     *  @param duration        Duration over which the yield will be realized.
     *  @param metadata        Optional metadata associated with the yield.
     */
    event YieldRealized(
        address indexed caller,
        uint256 unrealizedYield,
        uint256 netYield,
        uint256 delegateFee,
        uint256 protocolFee,
        uint256 recordedAssets,
        uint32  duration,
        bytes   metadata
    );

    /**************************************************************************************************************************************/
    /*** Liquidity Management Functions                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Acknowledges assets have been funded to the strategy.
     *          Callable only by the strategy manager.
     *  @param  assetsIn  Amount of assets that have been transferred to the strategy.
     *  @param  data      Unused, but reserved for future strategy-specific calldata.
     *  @return assetsOut Value of transferred assets after the funding.
     *                    Equal to the amount of assets that were transferred.
     */
    function fundUnderlyingStrategy(uint256 assetsIn, bytes calldata data) external returns (uint256 assetsOut);

    /**
     *  @dev   Withdraws assets from the strategy to a specific address.
     *         Callable only by the strategy manager.
     *         Only assets sitting in the allocation strategy can be withdrawn.
     *  @param destination Address to send the assets to.
     *  @param assets      Amount of assets to withdraw.
     *  @param data        Unused, but reserved for future strategy-specific calldata.
     */
    function withdrawFromUnderlyingStrategy(address destination, uint256 assets, bytes calldata data) external;

    /**
     *  @dev   Transfers assets from the strategy to the caller.
     *         Caller must be a valid managed wallet on MapleGlobals.
     *         Caller must have permission to deploy assets.
     *         Cannot deploy more assets than allowed by the deployment cap.
     *         Cannot deploy more assets than are currently available in the strategy.
     *  @param assets   Amount of assets to deploy.
     *  @param metadata Optional metadata associated with the deployment.
     */
    function deployAssets(uint256 assets, bytes calldata metadata) external;

    /**
     *  @dev   Transfers assets from the caller to the strategy.
     *         Caller must be a valid managed wallet on MapleGlobals.
     *         Caller must have permission to return assets.
     *         Cannot return more assets than were already deployed.
     *  @param assets     Amount of assets to return.
     *  @param onBehalfOf Address that will be credited as having returned the assets.
     *                    Can be the caller address.
     *  @param metadata   Optional metadata associated with assets being returned.
     */
    function returnAssets(uint256 assets, address onBehalfOf, bytes calldata metadata) external;

    /**
     *  @dev   Transfers assets from the caller to the yield buffer.
     *         Caller must be a valid managed wallet on MapleGlobals.
     *         Caller must have permission to realize yield.
     *         Can only be called once per hour across all managed wallets.
     *         Zero assets is valid and only updates the duration of the yield buffer.
     *         Zero duration is valid and causes all yield to be realized immediately.
     *         Cannot realize more assets than allowed by the yield cap.
     *  @param assets   Amount of assets to realize as yield.
     *  @param duration Duration over which to realize assets in seconds.
     *  @param metadata Optional metadata associated with the yield.
     */
    function realizeYield(uint256 assets, uint32 duration, bytes calldata metadata) external;

    /**
     *  @dev   Cancels unrealized yield from the yield buffer and transfers it to the recipient.
     *         Callable only by the strategy delegate or security admin.
     *         Already-realized yield cannot be cancelled.
     *         Remaining unrealized yield continues on its original schedule.
     *  @param assets    Amount of unrealized yield to cancel.
     *                   Can use `type(uint256).max` to cancel all remaining unrealized yield.
     *  @param recipient Address to receive the cancelled yield. Must be a valid managed wallet on globals.
     */
    function cancelYield(uint256 assets, address recipient) external;

    /**
     *  @dev   Increases the amount of impaired assets.
     *         Callable only by the strategy delegate or operational admin.
     *  @param assets Amount of assets to impair.
     */
    function impair(uint256 assets) external;

    /**
     *  @dev   Decreases the amount of impaired assets.
     *         Callable only by the strategy delegate or operational admin.
     *  @param assets Amount of assets to unimpair.
     */
    function removeImpairment(uint256 assets) external;

    /**
     *  @dev   Recognizes a loss against a deployer, reducing their deployed amount and total outstanding assets.
     *         Callable only by the strategy delegate or operational admin.
     *         Cannot exceed the deployer's currently deployed amount.
     *  @param assets   Amount of assets to recognize as lost.
     *  @param deployer Address of the deployer the loss is attributed to.
     */
    function recognizeLoss(uint256 assets, address deployer) external;

    /**
     *  @dev   Recognizes a loss and reduces an impairment simultaneously.
     *         Callable only by the strategy delegate or operational admin.
     *         Cannot exceed the deployer's currently deployed amount.
     *  @param assetsLost       Amount of assets to recognize as lost.
     *  @param assetsUnimpaired Amount of assets to unimpair.
     *  @param deployer         Address of the deployer the loss is attributed to.
     */
    function recognizeLossAndRemoveImpairment(uint256 assetsLost, uint256 assetsUnimpaired, address deployer) external;

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Sets the deployment cap for a list of managed wallets.
     *         Callable only by the strategy delegate or security admin.
     *  @param accounts Managed wallets to set deployment caps for.
     *  @param amounts  New deployment cap to set for each managed wallet.
     */
    function setDeploymentCaps(address[] calldata accounts, uint256[] calldata amounts) external;

    /**
     *  @dev   Updates the metadata of the allocation strategy.
     *         Callable only by the strategy delegate or operational admin.
     *  @param metadata Optional metadata associated with the strategy.
     */
    function setMetadata(string calldata metadata) external;

    /**
     *  @dev   Sets permissions for a list of managed wallets.
     *         Callable only by the strategy delegate or operational admin.
     *         Addresses must be valid managed wallets on MapleGlobals to receive any enabled permission.
     *  @param accounts        Managed wallets to set permissions for.
     *  @param canDeployAssets Defines if each address can call deployAssets().
     *  @param canReturnAssets Defines if each address can call returnAssets().
     *  @param canRealizeYield Defines if each address can call realizeYield().
     */
    function setPermissions(
        address[] calldata accounts,
        bool[]    calldata canDeployAssets,
        bool[]    calldata canReturnAssets,
        bool[]    calldata canRealizeYield
    ) external;

    /**
     *  @dev   Sets the percentage of yield collected by the strategy delegate.
     *         Callable only by the strategy delegate.
     *         The combined strategy delegate and protocol fee rates cannot exceed 1e6.
     *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate) external;

    /**
     *  @dev   Sets the percentage of yield collected by the Maple treasury.
     *         Callable only by protocol admins.
     *         The combined strategy delegate and protocol fee rates cannot exceed 1e6.
     *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury, defined with 6 decimals
     *                                 of precision (1e6 == 100%).
     */
    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate) external;

    /**
     *  @dev   Sets the maximum amount of assets that can be supplied as the `assets` parameter of realizeYield().
     *         Callable only by the strategy delegate or operational admin.
     *  @param yieldCap Maximum amount of assets that can be realized as yield in a single call.
     */
    function setYieldCap(uint256 yieldCap) external;

    /**
     *  @dev   Transfers all assets held by the strategy that have not been recorded to a given recipient.
     *         Callable only by the strategy delegate or operational admin.
     *         Does not affect the recorded assets, and therefore does not affect the assets under management.
     *  @param recipient Address that will receive the unrecorded assets.
     */
    function skim(address recipient) external;

    /**
     *  @dev   Allows EOAs to batch admin calls.
     *  @param data Array of calldata.
     */
    function multicall(bytes[] calldata data) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the amount of assets available for deployment or withdrawal.
     *          Equal to the recorded assets less the unrealized assets still sitting in the yield buffer.
     *          Assets that have not been recorded by the strategy are never available.
     *  @return availableToWithdraw Assets available for deployment or withdrawal.
     */
    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    /**
     *  @dev    Returns the total amount of assets managed by the strategy.
     *          Includes all deployed assets and recorded assets in the strategy, but doesn't include unrealized yield.
     *  @return assetsUnderManagement Total assets managed by the strategy.
     */
    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    /**
     *  @dev    Returns the address of the Maple Globals contract.
     *  @return globals Address of the Maple Globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the Maple treasury address which receives the protocol fees.
     *  @return mapleTreasury Address of the Maple treasury.
     */
    function mapleTreasury() external view returns (address mapleTreasury);

    /**
     *  @dev    Returns the current amount of yield assets that has been realized.
     *  @return realizedYield Amount of yield assets realized.
     */
    function realizedYield() external view returns (uint256 realizedYield);

    /**
     *  @dev    Returns the address of the security admin.
     *  @return securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

    /**
     *  @dev    Returns the strategy delegate that receives the delegate's share of accrued yield for the
     *          bound strategy manager.
     *  @return strategyDelegate Address of the strategy delegate.
     */
    function strategyDelegate() external view returns (address strategyDelegate);

    /**
     *  @dev    Returns the amount of assets held by the strategy that have not been recorded.
     *          Equal to the balance of the funds asset less the recorded assets, clamping at zero.
     *  @return unrecordedAssets Amount of assets held by the strategy that have not been recorded.
     */
    function unrecordedAssets() external view returns (uint256 unrecordedAssets);

    /**
     *  @dev    Returns the amount of unrealized losses.
     *          Equal to the amount of impaired assets capped to the AUM of the strategy.
     *  @return unrealizedLosses Amount of unrealized losses.
     */
    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    /**
     *  @dev    Returns the current amount of yield assets that has not been realized.
     *  @return unrealizedYield Amount of yield assets not yet realized.
     */
    function unrealizedYield() external view returns (uint256 unrealizedYield);

    /**
     *  @dev    Returns the number of seconds remaining until yield can be realized again.
     *  @return cooldown Number of seconds remaining in the yield cooldown period.
     */
    function yieldCooldown() external view returns (uint256 cooldown);

}
