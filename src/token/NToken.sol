// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title NToken - yield bearing token for the Multi Collateral Vault
/// @notice This contract implements the ERC20 interface for the yield bearing token

contract NToken is ERC20 {
    /// @notice ERC20 name for this token
    string public constant NAME = "NToken";

    /// @notice ERC20 symbol for this token
    string public constant SYMBOL = "NTKN";

    /// @notice ERC20 decimals for this token
    uint8 public constant DECIMALS = 18;

    /// @notice ERC20 total supply for this token
    uint256 public constant TOTAL_SUPPLY = 100000000000000000000000000;

    /// @notice ERC20 version for this token
    string public constant VERSION = "1";

    /// @notice ERC20 name for this token
    constructor() ERC20(NAME, SYMBOL, DECIMALS) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
