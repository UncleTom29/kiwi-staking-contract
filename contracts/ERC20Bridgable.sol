//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IERC20Bridgable.sol";

/**
 * @notice Bridge update proposal informations.
 * @param newBridge The address of the bridge proposed.
 * @param endGracePeriod The timestamp in second from when the proposal can be executed.
 */
struct BridgeUpdate {
    address newBridge;
    uint256 endGracePeriod;
}

/**
 * @notice ERC20 token smart contract with a mechanism for authorizing a bridge to mint and burn.
 */
contract ERC20Bridgable is ERC20, Ownable, IERC20Bridgable {
    using Address for address;

    // Address of the contract who will be able to mint and burn tokens
    address public bridge;
    // Latest update launched, executed or not
    BridgeUpdate public bridgeUpdate;

    modifier onlyBridge() {
        require(msg.sender == bridge, "ERC20Bridgable: access denied");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @notice Create a bridge update that can be executed after 7 days.
     * The 7 days period is there to enable holders to check the new bridge contract
     * before it starts to be used.
     * @dev Only executable by the owner of the contract.
     * @param newBridge Address of the new bridge.
     */
    function launchBridgeUpdate(address newBridge) external onlyOwner {
        // Check if there already is an update waiting to be executed
        require(
            bridgeUpdate.newBridge == address(0),
            "ERC20Bridgable: current update has to be executed"
        );
        // Make sure the new address is a contract and not an EOA
        require(newBridge.isContract(), "ERC20Bridgable: address provided is not a contract");

        uint256 endGracePeriod = block.timestamp + 1 weeks;

        bridgeUpdate = BridgeUpdate(newBridge, endGracePeriod);

        emit BridgeUpdateLaunched(newBridge, endGracePeriod);
    }

    /**
     * @notice Execute the update once the grace period has passed, and change the bridge address.
     * @dev Only executable by the owner of the contract.
     */
    function executeBridgeUpdate() external onlyOwner {
        // Check that grace period has passed
        require(
            bridgeUpdate.endGracePeriod <= block.timestamp,
            "ERC20Bridgable: grace period has not finished"
        );
        // Check that update have not already been executed
        require(bridgeUpdate.newBridge != address(0), "ERC20Bridgable: update already executed");

        bridge = bridgeUpdate.newBridge;
        emit BridgeUpdateExecuted(bridgeUpdate.newBridge);

        delete bridgeUpdate;
    }

    /**
     * @dev Enable the bridge to mint tokens in case they are received from Ethereum mainnet.
     * Only executable by the bridge contract.
     * @param account Address of the user who should receive the tokens.
     * @param amount Amount of token that the user should receive.
     */
    function mintFromBridge(address account, uint256 amount) external override onlyBridge {
        _mint(account, amount);
    }

    /**
     * @dev Enable the bridge to burn tokens in case they are sent to Ethereum mainnet.
     * Only executable by the bridge contract.
     * @param account Address of the user who is bridging the tokens.
     * @param amount Amount of token that the user is bridging.
     */
    function burnFromBridge(address account, uint256 amount) external override onlyBridge {
        _burn(account, amount);
    }
}
