// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAllocationStrategy } from "../../contracts/MapleAllocationStrategy.sol";
import { MapleAllocationStrategyInitializer } from "../../contracts/MapleAllocationStrategyInitializer.sol";

import { AllocationStrategyInitializerParams } from "../../contracts/interfaces/IMapleAllocationStrategyInitializer.sol";
import { Permissions } from "../../contracts/interfaces/IMapleAllocationStrategyStorage.sol";

contract MapleAllocationStrategyHarness is MapleAllocationStrategy {

    function __setDeployedAssetsOf(address account_, uint256 amount_) external {
        totalDeployedAssets        = totalDeployedAssets - deployedAssetsOf[account_] + amount_;
        deployedAssetsOf[account_] = amount_;
    }

    function __setDeploymentCapOf(address account_, uint256 cap_) external {
        deploymentCapOf[account_] = cap_;
    }

    function __setFeeRates(uint32 delegateFeeRate_, uint32 protocolFeeRate_) external {
        strategyDelegateFeeRate = delegateFeeRate_;
        strategyProtocolFeeRate = protocolFeeRate_;
    }

    function __setImpairedAssets(uint256 impairedAssets_) external {
        impairedAssets = impairedAssets_;
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

    function __setRecordedAssets(uint256 recordedAssets_) external {
        recordedAssets = recordedAssets_;
    }

    function __setYieldBuffer(uint256 yieldAssets_, uint32 yieldStart_, uint32 yieldDeadline_) external {
        scheduledYieldAssets = yieldAssets_;
        yieldStart           = yieldStart_;
        yieldDeadline        = yieldDeadline_;
    }

    function __setYieldCap(uint256 yieldCap_) external {
        yieldCap = yieldCap_;
    }

    function __setYieldLastRealized(uint32 yieldLastRealized_) external {
        yieldLastRealized = yieldLastRealized_;
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}

contract MapleAllocationStrategyInitializerHarness is MapleAllocationStrategyInitializer {

    function __initialize(address strategyManager_, AllocationStrategyInitializerParams memory params_) external {
        _initialize(strategyManager_, params_);
    }

    function locked() external view returns (uint256 locked_) {
        locked_ = _locked;
    }

}
