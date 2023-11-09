// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256) external;
}
