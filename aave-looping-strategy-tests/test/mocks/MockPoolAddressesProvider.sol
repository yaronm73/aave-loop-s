// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";

contract MockPoolAddressesProvider is IPoolAddressesProvider {
    address private _pool;
    address private _poolConfigurator;
    address private _priceOracle;

mapping(bytes32 => address) private _addresses;

function setPool(address pool) external {
    _addresses[keccak256("POOL")] = pool;
}

function getPool() external view returns (address) {
    return _addresses[keccak256("POOL")];
}

    function getPoolConfigurator() external view override returns (address) {
        return _poolConfigurator;
    }

    function setPoolConfigurator(address poolConfigurator) external {
        _poolConfigurator = poolConfigurator;
    }

    function getPriceOracle() external view override returns (address) {
        return _priceOracle;
    }

    function setPriceOracle(address priceOracle) external {
        _priceOracle = priceOracle;
    }

    // Stub implementations for other methods
    function getACLAdmin() external view override returns (address) {
        return address(0);
    }

    function getAddress(bytes32) external view override returns (address) {
        return address(0);
    }

    function getMarketId() external view override returns (string memory) {
        return "mock-market";
    }

    function getPoolDataProvider() external view override returns (address) {
        return address(0);
    }

    function setACLAdmin(address) external override {}

    function setACLManager(address) external override {}

    function setAddress(bytes32, address) external override {}

    function setAddressAsProxy(bytes32, address) external override {}

    function setMarketId(string calldata) external override {}

    function setPoolDataProvider(address) external override {}

    function setPoolImpl(address) external override {}

    function setPoolConfiguratorImpl(address) external override {}

    function setPriceOracleSentinel(address) external override {}

    function getACLManager() external view returns (address) {
        return address(0);
    }

    function getPriceOracleSentinel() external pure returns (address)   {
            return address(0);
    }   


}
