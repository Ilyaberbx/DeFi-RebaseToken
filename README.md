# DeFi Rebase Token

A cross-chain rebase token implementation with per-user interest rates and CCIP integration with custom "BurnAndMint" pool for seamless token bridging across blockchain networks.

## Overview

This system implements a rebase token (RBT) where users earn interest on their holdings based on time-locked interest rates. The protocol features decreasing global interest rates while allowing users to maintain their original interest rate from the time of deposit. Cross-chain functionality is achieved through Chainlink CCIP, enabling users to bridge tokens while preserving their individual interest rates.

## Architecture

The system consists of three core components:

### RebaseToken

ERC20 token with per-user interest rate linear accrual mechanism. The token balance increases over time based on the user's locked interest rate, calculated continuously since their last interaction.

**Key Characteristics:**
- Per-user interest rate tracking
- Global interest rate that can only decrease
- Automatic interest minting on token transfers
- Role-based access control for minting and burning
- Interest rate inheritance on transfers to empty wallets

**Interest Calculation:**
```
balance = principleBalance * (PRECISION_FACTOR + userInterestRate * timeElapsed) / PRECISION_FACTOR
```

Where:
- `PRECISION_FACTOR = 1e18`
- `userInterestRate` is locked at the time of deposit
- `timeElapsed` is seconds since last update

**State Variables:**
- `s_interestRate`: Global interest rate (initialized at 5e10, representing 0.05% per unit time)
- `s_userInterestRate`: Per-user interest rate mapping
- `s_userLastUpdatedTimestamp`: Timestamp tracking for interest calculation

**Access Control:**
- `MINT_AND_BURN_ROLE`: Required for minting and burning operations
- `onlyOwner`: Can set global interest rate and grant roles

### Vault

ETH collateralization contract enabling users to mint RBT tokens by depositing ETH at a 1:1 ratio.

**Functions:**
- `deposit()`: Accepts ETH and mints RBT at current global interest rate
- `redeem(uint256 amount)`: Burns RBT and returns equivalent ETH
- Supports `type(uint256).max` for full balance redemption

**Security:**
- Direct ETH transfers via low-level call
- Revert on failed redemption
- Immutable rebase token reference

### RebaseTokenPool

Chainlink CCIP TokenPool implementation for cross-chain token transfers. Handles burning on source chain and minting on destination chain while preserving user interest rates.

**CCIP Integration:**
- `lockOrBurn()`: Burns tokens on source chain, encodes user interest rate in pool data
- `releaseOrMint()`: Mints tokens on destination chain with preserved interest rate
- Validates chain selectors and receiver addresses through TokenPool base

**Cross-Chain Flow:**
1. User initiates CCIP transfer on source chain
2. Pool burns tokens from sender
3. User interest rate encoded in `destPoolData`
4. Destination pool decodes interest rate
5. Tokens minted to receiver with original interest rate intact

## Technical Specifications

**Solidity Version:** ^0.8.20

**Dependencies:**
- OpenZeppelin Contracts (ERC20, Ownable, AccessControl)
- Chainlink CCIP Contracts (TokenPool, Pool)

**Token Details:**
- Name: RebaseToken
- Symbol: RBT
- Decimals: 18

## Interest Rate Mechanics

### Global Interest Rate

The owner can decrease the global interest rate to manage protocol economics. This affects newly deposited funds but does not impact existing holders.

```solidity
function setInterestRate(uint256 newInterestRate) external onlyOwner
```

**Constraint:** `newInterestRate < s_interestRate` (can only decrease)

### User Interest Rate

Locked at the time of token minting. Preserved across:
- Token transfers (inherited by recipient if recipient balance is zero)
- Cross-chain bridges (encoded in CCIP pool data)
- Rebase calculations (stored per address)

### Interest Accrual

Interest accrues continuously based on block timestamp. Upon any token transfer, burn, or mint operation, accrued interest is minted to the user, updating the principle balance and resetting the timer.

## Cross-Chain Behavior

When bridging tokens via CCIP:

1. Source chain pool encodes `getUserInterestRate(sender)` in pool data
2. Tokens burned on source chain
3. Destination chain pool decodes interest rate from pool data
4. Tokens minted on destination chain with original user interest rate
5. User maintains same interest accrual rate across chains

This ensures economic equivalence across all supported chains.

## Transfer Mechanics

### Standard Transfer

```solidity
function transfer(address to, uint256 amount) public override returns (bool)
```

**Behavior:**
1. Mint accrued interest to sender
2. Mint accrued interest to recipient
3. If `amount == type(uint256).max`, transfer entire balance
4. If recipient balance is zero, inherit sender's interest rate
5. Execute transfer

This allows users to consolidate holdings from multiple wallets while maintaining the most favorable interest rate.

### TransferFrom

Identical mechanics to standard transfer but uses approval mechanism.

## Security Considerations

- Interest rates stored with 18 decimal precision to prevent rounding errors
- Timestamp-based interest calculation subject to minor block timestamp manipulation
- Vault redemption uses low-level call, vulnerable to gas griefing
- Role-based access control prevents unauthorized minting
- Interest rate decrease-only policy prevents protocol abuse
- No emergency pause mechanism implemented

## View Functions

**RebaseToken:**
- `balanceOf(address)`: Returns balance including accrued interest
- `getPrincipleBalanceOf(address)`: Returns balance excluding accrued interest
- `getUserInterestRate(address)`: Returns user's locked interest rate
- `getInterestRate()`: Returns current global interest rate
- `getUserLastUpdatedTimestamp(address)`: Returns last update timestamp
- `getPrecisionFactor()`: Returns precision factor constant

**Vault:**
- `getRebaseTokenAddress()`: Returns RBT token address

## Author

Illia Verbanov

