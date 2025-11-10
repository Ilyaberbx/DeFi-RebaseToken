// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IRebaseToken
 * @author Illia Verbanov
 * @notice Interface for the RebaseToken contract.
 * @notice The interface is used to interact with the RebaseToken contract.
 */
interface IRebaseToken {
    /**
     * @notice Mints new tokens to the specified address.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     * @param interestRate The interest rate for the tokens.
     */
    function mint(address to, uint256 amount, uint256 interestRate) external;
    /**
     * @notice Burns the specified amount of tokens from the specified address.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external;
    /**
     * @notice Gets the principle balance of the specified user.
     * @param user The address to get the balance for.
     * @return The balance of the specified user.
     */
    function balanceOf(address user) external view returns (uint256);
    /**
     * @notice Gets the global interest rate for the token.
     * @return The global interest rate for the token.
     */
    function getInterestRate() external view returns (uint256);
    /**
     * @notice Gets the interest rate for the specified user.
     * @param user The address to get the interest rate for.
     * @return The interest rate for the specified user.
     */
    function getUserInterestRate(address user) external view returns (uint256);
    /**
     * @notice Grants the mint and burn role to the specified address.
     * @param user The address to grant the mint and burn role to.
     */
    function grantMintAndBurnRole(address user) external;
}
