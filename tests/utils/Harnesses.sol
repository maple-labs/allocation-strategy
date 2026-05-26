// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleTradingStrategy }            from "../../contracts/MapleTradingStrategy.sol";
import { MapleTradingStrategyInitializer } from "../../contracts/MapleTradingStrategyInitializer.sol";

contract MapleTradingStrategyHarness is MapleTradingStrategy {

    function __setDeployedAssetsOf(address account_, uint256 amount_) external {
        outstandingAssets = outstandingAssets - deployedAssetsOf[account_] + amount_;
        deployedAssetsOf[account_] = amount_;
    }

    function __setDeploymentCapOf(address account_, uint256 cap_) external {
        deploymentCapOf[account_] = cap_;
    }

    function __setLocked(uint256 locked_) external {
        _locked = locked_;
    }

    function __setPermissions(address account_, bool allowed_) external {
        permissions[account_] = Permissions({
            canDeployAssets: allowed_,
            canReturnAssets: allowed_,
            canRealizeYield: allowed_
        });
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
