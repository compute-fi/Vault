// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface ICompoundUSDCV3 {
    function allow(address who, bool status) external;

    function supply(address asset, uint amount) external;

    function withdraw(address asset, uint requestedAmount) external;

    function withdrawTo(address to, address asset, uint amount) external;
}
