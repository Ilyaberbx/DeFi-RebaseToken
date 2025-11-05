// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {RebaseTokenPool} from "../../src/RebaseTokenPool.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";

import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract CrossChainTest is Test {
    string private constant SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    string private constant ARB_SEPOLIA_RPC_URL = vm.envString("ARB_SEPOLIA_RPC_URL");

    uint256 private sepoliaFork;
    uint256 private arbSepoliaFork;
    CCIPLocalSimulatorFork private ccipLocalSimulatorFork;
    RebaseToken private sepoliaToken;
    RebaseToken private arbSepoliaToken;
    RebaseTokenPool private sepoliaTokenPool;
    RebaseTokenPool private arbSepoliaTokenPool;
    Register.NetworkDetails private sepoliaNetworkDetails;
    Register.NetworkDetails private arbSepoliaNetworkDetails;
    Vault private sepoliaVault;
    address private owner = makeAddr("owner");

    function setUp() public {
        // Setup forks
        sepoliaFork = vm.createSelectFork(SEPOLIA_RPC_URL);
        arbSepoliaFork = vm.createSelectFork(ARB_SEPOLIA_RPC_URL);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Sepolia
        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken(owner);
        sepoliaVault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sepoliaTokenPool = new RebaseTokenPool(
            IRebaseToken(address(sepoliaToken)),
            address[](0),
            sepoliaNetworkDetails.rmnProxy,
            sepoliaNetworkDetails.router
        );
        sepoliaToken.grantMintAndBurnRole(address(sepoliaTokenPool));
        sepoliaTokenPool.grantMintAndBurnRoles(address(sepoliaVault));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken), address(sepoliaTokenPool));
        configureTokenPool(sepoliaFork, address(sepoliaTokenPool), arbSepoliaNetworkDetails.chainSelector, address(arbSepoliaTokenPool), address(arbSepoliaToken));

        // Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaToken = new RebaseToken(owner);
        arbSepoliaVault = new Vault(IRebaseToken(address(arbSepoliaToken)));
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaTokenPool = new RebaseTokenPool(
            IRebaseToken(address(arbSepoliaToken)),
            address[](0),
            arbSepoliaNetworkDetails.rmnProxy,
            arbSepoliaNetworkDetails.router
        );

        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaTokenPool));
        
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken), address(arbSepoliaTokenPool));
        configureTokenPool(arbSepoliaFork, address(arbSepoliaTokenPool), sepoliaNetworkDetails.chainSelector, address(sepoliaTokenPool), address(sepoliaToken));
        vm.stopPrank();
    }

    function configureTokenPool(uint256 forkId, address localPoolAddress, uint64 remoteChainSelector, address remotePoolAddress, address remoteTokenAddress) public {
        vm.selectFork(forkId);
        vm.prank(owner);

        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePoolAddress);

        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            allowed: true,
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        TokenPool(localPoolAddress).applyChainUpdates(
            new uint64[](0),
        );
    }
}
