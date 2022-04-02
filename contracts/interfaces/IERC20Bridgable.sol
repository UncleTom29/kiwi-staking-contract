// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20Bridgable {
    function mintFromBridge(address account, uint256 amount) external;

    function burnFromBridge(address account, uint256 amount) external;

    event BridgeUpdateLaunched(address indexed newBridge, uint256 endGracePeriod);
    event BridgeUpdateExecuted(address indexed newBridge);
}
