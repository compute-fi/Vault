// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ICERC20} from "../interfaces/Compound/ICERC20.sol";

/// @notice Get up to date cToken data without mutating the state of the cToken

library LibCompound {
    using FixedPointMathLib for uint256;

    error RATE_TOO_HIGH();

    function viewUnderlyingBalanceOf(
        ICERC20 cToken,
        address user
    ) internal view returns (uint256) {
        return cToken.balanceOf(user).mulWadDown(viewExchangeRate(cToken));
    }

    function viewExchangeRate(ICERC20 cToken) internal view returns (uint256) {
        uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();

        if (accrualBlockNumberPrior == block.number) {
            return cToken.exchangeRateStored();
        }

        uint256 totalCash = cToken.underlying().balanceOf(address(cToken));
        uint256 borrowsPrior = cToken.totalBorrows();
        uint256 reservesPrior = cToken.totalReserves();

        uint256 borrowRateMantissa = cToken.interestRateModel().getBorrowRate(
            totalCash,
            borrowsPrior,
            reservesPrior
        );

        if (borrowRateMantissa > 0.0005e16) revert RATE_TOO_HIGH();

        uint256 interestAccumulated = borrowRateMantissa *
            block.number -
            accrualBlockNumberPrior.mulWadDown(borrowsPrior);

        uint256 totalReserves = cToken.reserveFactorMantissa().mulWadDown(
            interestAccumulated
        ) + reservesPrior;
        uint256 totalBorrows = interestAccumulated + borrowsPrior;
        uint256 totalSupply = cToken.totalSupply();

        return
            totalSupply == 0
                ? cToken.initialExchangeRateMantissa()
                : totalCash +
                    totalBorrows -
                    totalReserves.divWadDown(totalSupply);
    }
}
