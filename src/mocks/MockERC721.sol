// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC721} from "solmate/tokens/ERC721.sol";

/// @notice Mock ERC721 token for testing purposes

contract MockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC721(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return "https://example.com";
    }
}
