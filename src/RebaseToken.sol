// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Illia Verbanov
 * @notice This contract is a cross-chain rebase token that incentivizes users to hold the token and participate in the rebase to earn rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 currentInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor(uint256 initialInterestRate) ERC20("RebaseToken", "RBT") {
        s_interestRate = initialInterestRate;
    }

    /**
     * @notice Sets the interest rate for the token.
     * @param newInterestRate The new interest rate to set.
     * @dev The interest rate can only decrease.
     */
    function setInterestRate(uint256 newInterestRate) external {
        if (newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(newInterestRate, s_interestRate);
        }
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    /**
     * @notice Mints new tokens to the specified address.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    /**
     * @notice Burns the specified amount of tokens from the specified address.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external {
        if(amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    /**
     * @notice Gets the interest rate for the specified user.
     * @param user The address to get the interest rate for.
     * @return The interest rate for the specified user.
     */
    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    /**
     * @notice Overrides the balanceOf function to return the balance of the specified user with the accrued interest.
     * @param user The address to get the balance for.
     * @return The balance of the specified user.
     */
    function balanceOf(address user) public view override returns (uint256) {
        return super.balanceOf(user) * _calculateAccruedInterestSinceLastUpdate(user) / PRECISION_FACTOR;
    }
    
    /**
     * @notice Mints the accrued interest for the specified user.
     * @param user The address to mint the accrued interest for.
     */
    function _mintAccruedInterest(address user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(user);
        uint256 currentBalance = balanceOf(user);
        uint256 accruedInterest = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        _mint(user, accruedInterest);
    }

    /**
     * @notice Calculates the accrued interest since the last update for the specified user.
     * @param user The address to calculate the accrued interest for.
     * @return The accrued interest since the last update for the specified user.
     */
    function _calculateAccruedInterestSinceLastUpdate(address user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        return PRECISION_FACTOR + (s_userInterestRate[user] * timeElapsed);
    }
}
