// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(
        address localPool,
        address remotePool,
        uint64 remoteChainSelector,
        address remoteToken,
        bool outBoundRateLimiterIsEnabled,
        uint128 outBountRateLimiterCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterIsEnabled,
        uint128 inBoundRateLimiterCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outBoundRateLimiterIsEnabled,
                capacity: outBountRateLimiterCapacity,
                rate: outBoundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inBoundRateLimiterIsEnabled,
                capacity: inBoundRateLimiterCapacity,
                rate: inBoundRateLimiterRate
            })
        });

        vm.startBroadcast();
        TokenPool(localPool).applyChainUpdates(chainUpdates);
        vm.stopBroadcast();
    }
}
