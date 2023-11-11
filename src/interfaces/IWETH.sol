// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IWETH {
    function deposit() external payable;

    function approve(address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    function withdraw(uint256) external;
}
