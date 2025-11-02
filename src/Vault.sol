// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

/**
 * @title Vault
 * @author Illia Verbanov
 * @notice This contract is a vault that allows users to deposit ETH and mint RBT tokens.
 * @notice The vault is used to store the ETH and mint the RBT tokens to the users.
 * @notice The vault is used to redeem the RBT tokens for ETH to the users.
 */
contract Vault {
    error Vault__RedeemFailed();
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Deposits ETH into the vault and mints RBT tokens to the sender.
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems RBT tokens for ETH from the vault and transfers the ETH to the sender.
     * @param amount The amount of RBT tokens to redeem.
     */
    function redeem(uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, amount);
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, amount);
    }

    /**
     * @notice Gets the address of the rebase token.
     * @return The address of the rebase token.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
