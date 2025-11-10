// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract RevertOnReceive {
    uint8 private s_recieveTimesBeforeRevert;

    constructor(uint8 recieveTimesBeforeRevert) {
        s_recieveTimesBeforeRevert = recieveTimesBeforeRevert;
    }
    receive() external payable {
        if (s_recieveTimesBeforeRevert == 0) {
            revert("Revert for test purposes");
        }
        s_recieveTimesBeforeRevert--;
    }
}
