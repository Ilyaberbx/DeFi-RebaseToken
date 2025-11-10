// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {RevertOnReceive} from "../mock/RevertOnReceive.test.sol";

contract VaultTest is Test {
    uint256 private constant AMOUNT_TO_DEPOSIT = 1e18;
    address private owner = makeAddr("owner");
    address private user = makeAddr("user");
    RebaseToken private rebaseToken;
    Vault private vault;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken(owner);
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testDeposit() public {
        vm.startPrank(user);
        vm.deal(user, AMOUNT_TO_DEPOSIT);
        vault.deposit{value: AMOUNT_TO_DEPOSIT}();
        assertEq(rebaseToken.balanceOf(user), AMOUNT_TO_DEPOSIT);
        assertEq(address(user).balance, 0);
        vm.stopPrank();
    }

    function testRedeemWithMaxAmountStandardFlow() public {
        vm.startPrank(user);
        vm.deal(user, AMOUNT_TO_DEPOSIT);
        vault.deposit{value: AMOUNT_TO_DEPOSIT}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        vault.redeem(type(uint256).max);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        assertGt(initialBalance, finalBalance);
        assertEq(finalBalance, 0);
        assertEq(address(user).balance, AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }

    function testRedeemWithCertainAmount() public {
        vm.startPrank(user);
        vm.deal(user, AMOUNT_TO_DEPOSIT);
        vault.deposit{value: AMOUNT_TO_DEPOSIT}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        vault.redeem(AMOUNT_TO_DEPOSIT - 1e9);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        assertGt(initialBalance, finalBalance);
        assertEq(finalBalance, 1e9);
    }

    function testRedeemRevertsIfRedeemFailed() public {
        address revertOnReceiveUser = address(new RevertOnReceive(0));
        vm.startPrank(revertOnReceiveUser);
        vm.deal(revertOnReceiveUser, AMOUNT_TO_DEPOSIT);
        vault.deposit{value: AMOUNT_TO_DEPOSIT}();
        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vault.redeem(type(uint256).max);
        vm.stopPrank();
    }
}
