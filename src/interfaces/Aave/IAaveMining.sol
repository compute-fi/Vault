// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

interface IAaveMining {
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getUserUnclaimedRewards(
        address user
    ) external view returns (uint256);
}
