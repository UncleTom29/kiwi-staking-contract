// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./ERC20Bridgable.sol";

contract KiwiEth is ERC20Bridgable {
    // Addresses authorized to mint tokens are set to true
    mapping(address => bool) public minters;
    // Addresses authorized to send tokens are set to true
    mapping(address => bool) public senders;
    // Addresses authorized to receive tokens are set to true
    mapping(address => bool) public receivers;

    event MinterSet(address account, bool authorized);
    event SenderSet(address account, bool authorized);
    event ReceiverSet(address account, bool authorized);

    constructor(string memory name, string memory symbol) ERC20Bridgable(name, symbol) {}

    /**
     * @notice Change the minter state of an address.
     * @dev Only callable by owner.
     * @param account Address to configure.
     * @param authorized True to enable address to mint, false to disable.
     */
    function setMinter(address account, bool authorized) external onlyOwner {
        minters[account] = authorized;
        emit MinterSet(account, authorized);
    }

    /**
     * @notice Change the sender state of an address.
     * @dev Only callable by owner.
     * @param account Address to configure.
     * @param authorized True to enable address to send, false to disable.
     */
    function setSender(address account, bool authorized) external onlyOwner {
        senders[account] = authorized;
        emit SenderSet(account, authorized);
    }

    /**
     * @notice Change the receiver state of an address.
     * @dev Only callable by owner.
     * @param account Address to configure.
     * @param authorized True to enable address to receive, false to disable.
     */
    function setReceiver(address account, bool authorized) external onlyOwner {
        receivers[account] = authorized;
        emit ReceiverSet(account, authorized);
    }

    /**
     * @notice Mint tokens for an account.
     * @dev Only callable by an authorized minter, check is done in _beforeTokenTransfer hook.
     * @param account Address to mint for.
     * @param amount Amount to mint.
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @dev Override ERC20 hook to check transfer authorizations.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Calls previous actions
        super._beforeTokenTransfer(from, to, amount);
        if (from == address(0)) {
            // If transfer is minting, checks that msg.sender is an authorized minter
            require(minters[msg.sender], "KiwiEth: sender is not an authorized minter");
        } else {
            // Otherwise check that sender or receiver are authorized
            require(senders[from] || receivers[to], "KiwiEth: transfer not authorized");
        }
    }
}
