// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20("Test token", "TST") {
    constructor() {
        _mint(msg.sender, type(uint256).max);
    }
}
