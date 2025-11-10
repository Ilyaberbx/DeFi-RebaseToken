// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

/**
 * @title RebaseTokenPool
 * @author Illia Verbanov
 * @notice This contract is a pool that allows users to lock and burn tokens and mint tokens to the users.
 * @notice The pool is used to store the tokens and mint the tokens to the users.
 * @notice The pool is used to redeem the tokens for the users.
 */
contract RebaseTokenPool is TokenPool {
    constructor(IERC20 token, address[] memory allowlist, address rmnProxy, address router) TokenPool(token, allowlist, rmnProxy, router) {}

    /**
     * @notice Burns the tokens from the sender (called by CCIP).
     * @param lockOrBurnIn The input data for the lock or burn operation.
     * @return lockOrBurnOut The output data for the lock or burn operation.
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        uint256 userInterestRate = _getUserInterestRate(lockOrBurnIn.originalSender);
        _burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @notice Mints the tokens to the receiver (called by CCIP).
     * @param releaseOrMintIn The input data for the release or mint operation.
     * @return releaseOrMintOut The output data for the release or mint operation.
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns (Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        _mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }

    /**
     * @notice Gets the interest rate for the specified user.
     * @param user The address to get the interest rate for.
     * @return The interest rate for the specified user.
     */
    function _getUserInterestRate(address user) internal view returns (uint256) {
        return IRebaseToken(address(i_token)).getUserInterestRate(user);
    }

    /**
     * @notice Burns the tokens from the specified address.
     * @param user The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address user, uint256 amount) internal {
        IRebaseToken(address(i_token)).burn(user, amount);
    }

    function _mint(address user, uint256 amount, uint256 interestRate) internal {
        IRebaseToken(address(i_token)).mint(user, amount, interestRate);
    }
}
