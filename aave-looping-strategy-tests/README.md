**AaveLoopingStrategy**

AaveLoopingStrategy is a smart contract designed for automated yield farming using Aave and Uniswap. The strategy deposits assets into Aave, borrows ETH, swaps it for wstETH via Uniswap, and re-deposits it into Aave to maximize yield while maintaining a safe health factor.

**Architecture Decisions**

1. Modular Strategy Design

The strategy extends BaseStrategy, inheriting core functionality such as deposits, withdrawals, and fund management.

Custom logic is implemented in _deployFunds, _freeFunds, and _harvestAndReport to interact with Aave and Uniswap.

2. Looping Mechanism

The _executeLoop function implements the looping strategy:

Deposits collateral in Aave.

Borrows ETH.

Swaps ETH for wstETH.

Deposits wstETH back into Aave.

The loop terminates when the health factor reaches maxHealthFactor.

3. Controlled Unwinding of Loans

The _withdraw function gradually unwinds borrowed assets before withdrawing collateral.

Repays ETH debt by swapping wstETH back to ETH and using it to repay Aave.

Ensures safe withdrawals without liquidation risk.

4. Security

Uses OpenZeppelin's SafeERC20 to prevent unsafe token interactions.

Immutable variables (swapRouter, aavePool) prevent unauthorized contract replacement.

Health factor thresholds (maxHealthFactor, minHealthFactor) ensure safe leverage ratios.



Assumptions

Aave and Uniswap as trusted Protocols

Uses OpenZeppelin libraries to mitigate common Solidity vulnerabilities.

Calls to external contracts are safeguarded with explicit checks.

The strategy does not use on-chain price oracles directly.

Relies on Aave's internal interest rates and Uniswap's spot swaps, assuming these mechanisms are resistant to manipulation.

Only the Owner Can Trigger Deposits & Withdrawals

The strategy does not accept direct user deposits but interacts through a higher-level vault.

Assumes that only authorized entities interact with the contract.

Gas Fees and MEV Are Acceptable Risks

Swapping ETH <-> wstETH on Uniswap could be challenged to MEV attacks and slippage.








## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
