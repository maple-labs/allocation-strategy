// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxied } from "../../modules/proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleTradingStrategyStorage } from "./IMapleTradingStrategyStorage.sol";

/**
 *  @title Defines a Maple trading strategy.
 */
interface IMapleTradingStrategy is IMapleTradingStrategyStorage, IMapleProxied {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when assets are deployed.
     *  @param deployer Address that deployed the assets.
     *  @param assets   Amount of assets deployed.
     *  @param metadata Optional metadata associated with the deployment.
     */
    event AssetsDeployed(address indexed deployer, uint256 assets, bytes metadata);

    /**
     *  @dev   Emitted when deployed assets are returned to the strategy.
     *  @param caller     Address that transferred the assets back.
     *  @param onBehalfOf Address to which the returned assets were credited.
     *  @param assets     Amount of assets returned.
     *  @param metadata   Optional metadata associated with the repayment.
     */
    event AssetsReturned(address indexed caller, address indexed onBehalfOf, uint256 assets, bytes metadata);

    /**
     *  @dev   Emitted when the deployment cap of a trading address is set.
     *  @param account       Trading address the cap was set for.
     *  @param deploymentCap New deployment cap for the trading address.
     */
    event DeploymentCapSet(address indexed account, uint256 deploymentCap);

    /**
     *  @dev   Emitted when assets are deployed into the trading strategy.
     *  @param strategyManager Address of the associated strategy manager.
     *  @param assets          Amount of assets transferred into the trading strategy.
     */
    event StrategyFunded(address indexed strategyManager, uint256 assets);

    /**
     *  @dev   Emitted when assets are withdrawn from the trading strategy.
     *  @param strategyManager Address of the associated strategy manager.
     *  @param destination     Address that received the withdrawn assets.
     *  @param assets          Amount of assets withdrawn from the trading strategy.
     */
    event StrategyWithdrawn(address indexed strategyManager, address indexed destination, uint256 assets);

    /**
     *  @dev   Emitted when yield is transferred to the yield buffer.
     *  @param caller          Address that transferred the yield.
     *  @param unrealizedYield Amount of unrealized yield carried over.
     *  @param netYield        Amount of net yield transferred.
     *  @param delegateFee     Amount of fees collected by the delegate.
     *  @param protocolFee     Amount of fees collected by the protocol.
     *  @param duration        Duration over which the yield will be realized.
     *  @param metadata        Optional metadata associated with the yield.
     */
    event YieldRealized(
        address indexed caller,
        uint256 unrealizedYield,
        uint256 netYield,
        uint256 delegateFee,
        uint256 protocolFee,
        uint32  duration,
        bytes   metadata
    );

    /**************************************************************************************************************************************/
    /*** Management Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Transfers assets from the strategy to the caller.
     *         Caller must be a valid trading address on MapleGlobals.
     *         Caller must have permission to deploy assets.
     *         Cannot deploy more assets than allowed by the deployment cap.
     *         Cannot deploy more assets than are currently available in the strategy.
     *  @param assets   Amount of assets to deploy.
     *  @param metadata Optional metadata associated with the deployment.
     */
    function deployAssets(uint256 assets, bytes calldata metadata) external;

    /**
     *  @dev   Transfers assets from the caller to the strategy.
     *         Caller must be a valid trading address on MapleGlobals.
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
     *         Caller must be a valid trading address on MapleGlobals.
     *         Caller must have permission to realize yield.
     *         Zero assets is valid and only updates the duration of the yield buffer.
     *         Zero duration is valid and causes all yield to be realized immediately.
     *  @param assets   Amount of assets to realize as yield.
     *  @param duration Duration over which to realize assets in seconds.
     *  @param metadata Optional metadata associated with the yield.
     */
    function realizeYield(uint256 assets, uint32 duration, bytes calldata metadata) external;

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Sets the deployment cap for a list of trading addresses.
     *         Callable only by the strategy delegate or operational admin.
     *  @param accounts Trading addresses to set deployment caps for.
     *  @param amounts  New deployment cap to set for each trading address.
     */
    function setDeploymentCaps(address[] calldata accounts, uint256[] calldata amounts) external;

    /**************************************************************************************************************************************/
    /*** Liquidity Functions                                                                                                            ***/
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
     *  @dev    Withdraws assets from the strategy to a specific address.
     *          Callable only by the strategy manager.
     *          Only assets sitting in the trading strategy can be withdrawn.
     *  @param  destination Address to send the assets to.
     *  @param  assets      Amount of assets to withdraw.
     */
    function withdrawFromUnderlyingStrategy(address destination, uint256 assets) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the amount of assets available for deployment or withdrawal.
     *          Does not include unrealized assets still sitting in the yield buffer.
     *  @return availableToWithdraw Assets available for deployment or withdrawal.
     */
    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

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
     *  @return realizedAssets Amount of yield assets realized.
     */
    function realizedAssets() external view returns (uint256 realizedAssets);

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
     *  @dev    Returns the current amount of yield assets that has not been realized.
     *  @return unrealizedAssets Amount of yield assets not yet realized.
     */
    function unrealizedAssets() external view returns (uint256 unrealizedAssets);

}
