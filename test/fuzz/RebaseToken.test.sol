// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseTokenTest is Test {
    error RebaseTokenTest__FailedToDepositETHIntoVault();

    RebaseToken private rebaseToken;
    Vault private vault;

    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken(owner);
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        vm.startPrank(owner);
        vm.deal(owner, amount);
        (bool success,) = payable(address(vault)).call{value: amount}("");
        vm.stopPrank();
    }

    function testLinearRebaseOnceDeposited(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);
        console.log("initialBalance", initialBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, initialBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        console.log("finalBalance", finalBalance);
        assertGt(finalBalance, middleBalance);
        assertApproxEqAbs(finalBalance - middleBalance, middleBalance - initialBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        console.log("initialBalance", initialBalance);
        assertEq(initialBalance, amount);
        vault.redeem(initialBalance);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint32).max);

        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        console.log("initialBalance", initialBalance);
        assertEq(initialBalance, amount);
        vm.warp(block.timestamp + time);
        uint256 finalBalance = rebaseToken.balanceOf(user);
        console.log("finalBalance", finalBalance);
        assertGt(finalBalance, initialBalance);
        vm.stopPrank();
        addRewardsToVault(finalBalance - amount);
        vm.startPrank(user);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, finalBalance);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 user1Balance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(user1Balance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        assertEq(rebaseToken.balanceOf(user), user1Balance - amountToSend);
        assertEq(rebaseToken.balanceOf(user2), user2Balance + amountToSend);
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotGrantMintAndBurnRoleIfNotOwner(address to) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.grantMintAndBurnRole(to);
    }

    function testGetPrincipleBalanceOf(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.getPrincipleBalanceOf(user), amount);
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), amount);
        vm.stopPrank();
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
