// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

library AddressLib {
    // @dev Vault Name and Symbol
    string constant VAULT_NAME = "Multi Collateral Vault";
    string constant VAULT_SYMBOL = "MCV";

    /// @dev Compound V3 Stablecoin Contracts on Mumbai
    address constant COMP_DAI = 0x4DAFE12E1293D889221B1980672FE260Ac9dDd28;
    address constant COMP_USDC = 0xDB3cB4f2688daAB3BFf59C24cC42D4B6285828e9;

    /// @dev Compound V3 Tokens
    address constant COMP_WETH = 0xE1e67212B1A4BF629Bdf828e08A3745307537ccE;
    address constant COMP_WBTC = 0x4B5A0F4E00bC0d6F16A593Cae27338972614E713;
    address constant COMP_WMATIC = 0xfec23a9E1DBA805ADCF55E0338Bf5E03488FC7Fb;

    /// @dev AAVE Stablecoin Contracts on Mumbai
    address constant AAVE_USDC = 0x52D800ca262522580CeBAD275395ca6e7598C014;
    address constant AAVE_USDT = 0x1fdE0eCc619726f4cD597887C9F3b4c8740e19e2;
    address constant AAVE_DAI = 0xc8c0Cf9436F4862a8F60Ce680Ca5a9f0f99b5ded;

    /// @dev Compound V3 USDC Contract on Mumbai
    address constant C_USDC_V3 = 0xF09F0369aB0a875254fB565E52226c88f10Bc839;

    /// @dev Aave V3 AToken
    address constant A_USDC_V3 = 0x52D800ca262522580CeBAD275395ca6e7598C014;
    address constant A_USDT_V3 = 0x5F3a71D07E95C1E54B9Cc055D418a219586A3473;
    address constant A_DAI_V3 = 0x8903bbBD684B7ef734c01BEb00273Ff52703514F;

    /// @dev Mask addresses
    uint256 internal constant ACTIVE_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;

    /// @notice Reference URL
    // https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses
    // https://docs.compound.finance/
}
