// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Import the original mock pool implementations
import {MockPoolInherited} from "@aave/contracts/mocks/helpers/MockPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";

contract MockAavePool is MockPoolInherited {
    mapping(address => uint256) private _supplyBalances;
    mapping(address => uint256) private _borrowBalances;
    mapping(address => uint256) private _supplyRates;
    mapping(address => uint256) private _borrowRates;

    constructor(IPoolAddressesProvider provider) MockPoolInherited(provider) {}

function supply(address asset, uint256 amount, address onBehalfOf, uint16) public override {
    _supplyBalances[asset] += amount;
}

function withdraw(address asset, uint256 amount, address to) public override returns (uint256) {
    require(_supplyBalances[asset] >= amount, "Insufficient balance in the pool");
    _supplyBalances[asset] -= amount;
    return amount;
}

    function setRates(address asset, uint256 supplyRate, uint256 borrowRate) external {
        _supplyRates[asset] = supplyRate;
        _borrowRates[asset] = borrowRate;
    }

    function simulateBorrow(address borrower, uint256 amount) external {
        _borrowBalances[borrower] += amount;
    }

    function supplyBalance(address asset) external view returns (uint256) {
        return _supplyBalances[asset];
    }

    function borrowBalance(address borrower) external view returns (uint256) {
        return _borrowBalances[borrower];
    }

    function getSupplyRate(address asset) external view returns (uint256) {
        return _supplyRates[asset];
    }

    function getBorrowRate(address asset) external view returns (uint256) {
        return _borrowRates[asset];
    }
}
