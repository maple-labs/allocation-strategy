// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleTradingStrategyStorage } from "../../contracts/MapleTradingStrategyStorage.sol";

contract MockAsset is MockERC20("Asset", "A", 6) {

    bool transferReverts;
    bool transferFromReverts;

    function __setTransferReverts(bool transferReverts_) external {
        transferReverts = transferReverts_;
    }

    function __setTransferFromReverts(bool transferFromReverts_) external {
        transferFromReverts = transferFromReverts_;
    }

    function transfer(address to_, uint256 amount_) public override returns (bool success_) {
        require(!transferReverts);

        success_ = super.transfer(to_, amount_);
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool success_) {
        require(!transferFromReverts);

        success_ = super.transferFrom(from_, to_, amount_);
    }

}

contract MockFactory {

    mapping(address => bool) public isInstance;

    function __setIsInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockGlobals {

    address public governor;
    address public securityAdmin;

    bool public protocolPaused;

    mapping(address => bool) public canDeploy;

    mapping(bytes4 => bool) public isFunctionPaused;

    function __setCanDeploy(address caller_, bool canDeploy_) external {
        canDeploy[caller_] = canDeploy_;
    }

    function __setGovernor(address governor_) external {
        governor = governor_;
    }

    function __setIsFunctionPaused(bytes4 signature_, bool isFunctionPaused_) external {
        isFunctionPaused[signature_] = isFunctionPaused_;
    }

    function __setProtocolPaused(bool protocolPaused_) external {
        protocolPaused = protocolPaused_;
    }

    function __setSecurityAdmin(address securityAdmin_) external {
        securityAdmin = securityAdmin_;
    }

}

contract MockManager {}

contract MockMigrator is MapleTradingStrategyStorage {

    fallback() external {
        manager = abi.decode(msg.data, (address));
    }

}
