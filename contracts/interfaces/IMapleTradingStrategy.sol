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
     *  @dev   Emitted when assets are deployed into the trading strategy.
     *  @param strategyManager Address of the associated strategy manager.
     *  @param assets          Amount of assets transferred into the trading strategy.
     */
    event StrategyFunded(address indexed strategyManager, uint256 assets);

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
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

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the address of the Maple Globals contract.
     *  @return globals Address of the Maple Globals contract.
     */
    function globals() external view returns (address globals);

    /**
     *  @dev    Returns the address of the security admin.
     *  @return securityAdmin Address of the security admin.
     */
    function securityAdmin() external view returns (address securityAdmin);

}
