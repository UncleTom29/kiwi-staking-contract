// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function getTokens() external {
        _mint(msg.sender, type(uint256).max);
    }

    function fullApprove(address target) external {
        _approve(msg.sender, target, type(uint256).max);
    }
}
