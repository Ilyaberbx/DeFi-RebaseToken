// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
/**
 * @title RebaseToken
 * @author Illia Verbanov
 * @notice This contract is a cross-chain rebase token that incentivizes users to hold the token and participate in the rebase to earn rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 currentInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor(address initialOwner) ERC20("RebaseToken", "RBT") Ownable(initialOwner) {}

    /**
     * @notice Grants the mint and burn role to the specified address.
     * @param to The address to grant the mint and burn role to.
     */
    function grantMintAndBurnRole(address to) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, to);
    }

    /**
     * @notice Sets the interest rate for the token.
     * @param newInterestRate The new interest rate to set.
     * @dev The interest rate can only decrease.
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate >= s_interestRate) {
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
    function mint(address to, uint256 amount, uint256 interestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = interestRate;
        _mint(to, amount);
    }

    /**
     * @notice Burns the specified amount of tokens from the specified address.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    /**
     * @notice Transfers the specified amount of tokens to the specified address.
     * @notice Minting accrued interest for the sender and the recipient before the transfer.
     * @notice If the recipient has no balance, the sender's interest rate is set for the recipient.
     * @notice If the amount to transfer is the maximum value, the entire balance of the sender is transferred.
     * @notice This flow provides ability to mint low amount of tokens with a high interest rate, and after some period of time, the user can transfer the tokens from another wallet to first wallet and the interest rate will be the same.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers the specified amount of tokens from the specified address to the specified address.
     * @notice Minting accrued interest for the sender and the recipient before the transfer.
     * @notice If the recipient has no balance, the sender's interest rate is set for the recipient.
     * @notice If the amount to transfer is the maximum value, the entire balance of the sender is transferred.
     * @notice This flow provides ability to mint low amount of tokens with a high interest rate, and after some period of time, the user can transfer the tokens from another wallet to first wallet and the interest rate will be the same.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) {
            amount = balanceOf(from);
        }
        if (balanceOf(to) == 0) {
            s_userInterestRate[to] = s_userInterestRate[from];
        }
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Gets the principle balance of the specified user.
     * @param user The address to get the principle balance for.
     * @return The principle balance of the specified user.
     */
    function getPrincipleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
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
     * @notice Gets the interest rate for the token.
     * @return The interest rate for the token.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Gets the last updated timestamp for the specified user.
     * @param user The address to get the last updated timestamp for.
     * @return The last updated timestamp for the specified user.
     */
    function getUserLastUpdatedTimestamp(address user) external view returns (uint256) {
        return s_userLastUpdatedTimestamp[user];
    }

    /**
     * @notice Gets the precision factor for the token.
     * @return The precision factor for the token.
     */
    function getPrecisionFactor() external pure returns (uint256) {
        return PRECISION_FACTOR;
    }
    /**
     * @notice Overrides the balanceOf function to return the balance of the specified user with the accrued interest.
     * @param user The address to get the balance for.
     * @return The balance of the specified user.
     */
    function balanceOf(address user) public view override returns (uint256) {
        return (super.balanceOf(user) * _calculateAccruedInterestSinceLastUpdate(user)) / PRECISION_FACTOR;
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
