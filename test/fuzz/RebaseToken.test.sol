// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseTokenTest is Test {
    error RebaseTokenTest__FailedToDepositETHIntoVault();

    RebaseToken private s_rebaseToken;
    Vault private s_vault;

    address private s_owner = makeAddr("owner");
    address private s_user = makeAddr("user");

    function setUp() public {
        vm.startPrank(s_owner);
        s_rebaseToken = new RebaseToken(s_owner);
        s_vault = new Vault(IRebaseToken(address(s_rebaseToken)));
        s_rebaseToken.grantMintAndBurnRole(address(s_vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        vm.startPrank(s_owner);
        vm.deal(s_owner, amount);
        (bool success, ) = payable(address(s_vault)).call{value: amount}("");
        vm.stopPrank();
    }
    function testLinearRebaseOnceDeposited(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(s_user, amount);
        vm.startPrank(s_user);
        s_vault.deposit{value: amount}();
        uint256 initialBalance = s_rebaseToken.balanceOf(s_user);
        assertEq(initialBalance, amount);
        console.log("initialBalance", initialBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = s_rebaseToken.balanceOf(s_user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, initialBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = s_rebaseToken.balanceOf(s_user);
        console.log("finalBalance", finalBalance);
        assertGt(finalBalance, middleBalance);
        assertApproxEqAbs(
            finalBalance - middleBalance,
            middleBalance - initialBalance,
            1
        );
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(s_user, amount);
        vm.startPrank(s_user);
        s_vault.deposit{value: amount}();
        uint256 initialBalance = s_rebaseToken.balanceOf(s_user);
        console.log("initialBalance", initialBalance);
        assertEq(initialBalance, amount);
        s_vault.redeem(initialBalance);
        assertEq(s_rebaseToken.balanceOf(s_user), 0);
        assertEq(address(s_user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint32).max);

        vm.deal(s_user, amount);
        vm.startPrank(s_user);
        s_vault.deposit{value: amount}();
        uint256 initialBalance = s_rebaseToken.balanceOf(s_user);
        console.log("initialBalance", initialBalance);
        assertEq(initialBalance, amount);
        vm.warp(block.timestamp + time);
        uint256 finalBalance = s_rebaseToken.balanceOf(s_user);
        console.log("finalBalance", finalBalance);
        assertGt(finalBalance, initialBalance);
        vm.stopPrank();
        addRewardsToVault(finalBalance - amount);
        vm.startPrank(s_user);
        s_vault.redeem(type(uint256).max);
        assertEq(s_rebaseToken.balanceOf(s_user), 0);
        assertEq(address(s_user).balance, finalBalance);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(s_user, amount);
        vm.prank(s_user);
        s_vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 user1Balance = s_rebaseToken.balanceOf(s_user);
        uint256 user2Balance = s_rebaseToken.balanceOf(user2);
        assertEq(user1Balance, amount);
        assertEq(user2Balance, 0);

        vm.prank(s_owner);
        s_rebaseToken.setInterestRate(4e10);

        vm.prank(s_user);
        s_rebaseToken.transfer(user2, amountToSend);

        assertEq(s_rebaseToken.balanceOf(s_user), user1Balance - amountToSend);
        assertEq(s_rebaseToken.balanceOf(user2), user2Balance + amountToSend);
        assertEq(s_rebaseToken.getUserInterestRate(s_user), 5e10);
        assertEq(s_rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRateIfNotOwner(
        uint256 newInterestRate
    ) public {
        vm.prank(s_user);
        vm.expectRevert();
        s_rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotGrantMintAndBurnRoleIfNotOwner(address to) public {
        vm.prank(s_user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        s_rebaseToken.grantMintAndBurnRole(to);
    }

    function testGetPrincipleBalanceOf(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(s_user, amount);
        vm.startPrank(s_user);
        s_vault.deposit{value: amount}();
        assertEq(s_rebaseToken.getPrincipleBalanceOf(s_user), amount);
        vm.warp(block.timestamp + 1 hours);
        assertEq(s_rebaseToken.getPrincipleBalanceOf(s_user), amount);
        vm.stopPrank();
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = s_rebaseToken.getInterestRate();
        newInterestRate = bound(
            newInterestRate,
            initialInterestRate,
            type(uint96).max
        );
        vm.prank(s_owner);
        vm.expectPartialRevert(
            RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector
        );
        s_rebaseToken.setInterestRate(newInterestRate);
        assertEq(s_rebaseToken.getInterestRate(), initialInterestRate);
    }
}
