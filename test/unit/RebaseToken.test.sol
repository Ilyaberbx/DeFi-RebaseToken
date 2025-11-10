// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    address private owner = makeAddr("owner");
    address private user = makeAddr("user");
    RebaseToken private rebaseToken;

    function setUp() public {
        rebaseToken = new RebaseToken(owner);
    }

    modifier grantMintAndBurnRole(address to) {
        vm.startPrank(owner);
        rebaseToken.grantMintAndBurnRole(to);
        vm.stopPrank();
        _;
    }

    function testGetInterestRate() public view {
        assertEq(rebaseToken.getInterestRate(), 5e10);
    }

    function testPrecisionFactorIsNotZero() public view {
        assertGt(rebaseToken.getPrecisionFactor(), 0);
    }

    function testGetLastUpdatedTimestamp() public grantMintAndBurnRole(user) {
        uint256 currentTimestamp = block.timestamp;
        vm.startPrank(user);
        rebaseToken.mint(user, 1e18, 1e18);
        vm.stopPrank();
        assertEq(rebaseToken.getUserLastUpdatedTimestamp(user), currentTimestamp);
    }

    function testConstructorAssignsZeroAddressAsOwner() public {
        vm.expectPartialRevert(Ownable.OwnableInvalidOwner.selector);
        new RebaseToken(address(0));
    }

    function testGrantMintAndBurnRoleIfNotOwner() public {
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.grantMintAndBurnRole(user);
    }

    function testGrantMintAndBurnRoleIfOwner() public grantMintAndBurnRole(user) {
        assertEq(rebaseToken.hasRole(keccak256("MINT_AND_BURN_ROLE"), user), true);
    }

    function testInterestRateCanOnlyDecrease() public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        vm.startPrank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(initialInterestRate + 1);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
        rebaseToken.setInterestRate(initialInterestRate - 1);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate - 1);
        vm.stopPrank();
    }

    function testMintAndBurnUnaccessibleForNonMintAndBurnRole() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 1e18, 1e18);
        vm.expectRevert();
        rebaseToken.burn(user, 1e18);
        vm.stopPrank();
    }

    function testMintAndBurnAccessibleForMintAndBurnRole() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        rebaseToken.mint(user, 1e18, 1e18);
        rebaseToken.burn(user, 1e18);
        vm.stopPrank();
    }

    function testMintAndInterestRateAccruedAfterTime() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;
        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        assertEq(rebaseToken.getUserInterestRate(user), interestRate);
        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfterTime = rebaseToken.balanceOf(user);
        assertGt(balanceAfterTime, principleBalance);
        assertEq(rebaseToken.getUserInterestRate(user), interestRate);
        vm.stopPrank();
    }

    function testBurnWithMaxAmountStandardFlow() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;
        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        rebaseToken.burn(user, type(uint256).max);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), 0);
        assertEq(rebaseToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testTransferWithMaxAmountStandardFlow() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;
        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        address user2 = makeAddr("user2");
        rebaseToken.transfer(user2, type(uint256).max);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), 0);
        assertEq(rebaseToken.getUserInterestRate(user2), interestRate);
        assertEq(rebaseToken.getPrincipleBalanceOf(user2), amountToMint);
        assertEq(rebaseToken.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testTransferWithCertainAmount() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;
        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        address user2 = makeAddr("user2");
        rebaseToken.transfer(user2, amountToMint - 1e9);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), 1e9);
        assertEq(rebaseToken.getUserInterestRate(user2), interestRate);
        assertEq(rebaseToken.getPrincipleBalanceOf(user2), amountToMint - 1e9);
        vm.stopPrank();
    }

    function testTransferFromWithMaxAmountStandardFlow() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;

        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        address user2 = makeAddr("user2");
        assertTrue(rebaseToken.approve(user2, amountToMint));
        vm.stopPrank();

        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, type(uint256).max);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), 0);
        assertEq(rebaseToken.getUserInterestRate(user2), interestRate);
        assertEq(rebaseToken.getPrincipleBalanceOf(user2), amountToMint);
    }

    function testTransferFromWithCertainAmount() public grantMintAndBurnRole(user) {
        vm.startPrank(user);
        uint256 amountToMint = 1e18;
        uint256 interestRate = 1e18;

        rebaseToken.mint(user, amountToMint, interestRate);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);
        assertEq(principleBalance, amountToMint);
        address user2 = makeAddr("user2");
        assertTrue(rebaseToken.approve(user2, amountToMint));
        vm.stopPrank();

        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, amountToMint);
        assertEq(rebaseToken.getPrincipleBalanceOf(user), 0);
        assertEq(rebaseToken.getUserInterestRate(user2), interestRate);
        assertEq(rebaseToken.getPrincipleBalanceOf(user2), amountToMint);
    }
}
