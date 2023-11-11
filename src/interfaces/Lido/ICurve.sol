// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface ICurve {
    function exchange(
        int128,
        int128,
        uint256,
        uint256
    ) external returns (uint256);

    function get_dy(int128, int128, uint256) external view returns (uint256);
}
