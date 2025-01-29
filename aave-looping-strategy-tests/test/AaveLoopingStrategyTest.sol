// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import "forge-std/Test.sol";
import "../src/AaveLoopingStrategy.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockSwapRouter} from "./mocks/MockSwapRouter.sol";
import {MockPoolAddressesProvider} from "./mocks/MockPoolAddressesProvider.sol";

contract AaveLoopingStrategyTest is Test {
    AaveLoopingStrategy private strategy;
    MockERC20 private asset;
    MockAavePool private aavePool;
    MockSwapRouter private swapRouter;
    MockPoolAddressesProvider private mockProvider;

    address private user = address(0x1234);
    uint256 private initialBalance = 1_000_000 ether;

function setUp() public {
    // Mainnet addresses for Aave V3 Pool and USDC
    address aavePoolAddress = 0x7beA39867E4169AcD0FC34D4A2e9aA3962E49e22; // Aave V3 Pool
    address swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap V3 SwapRouter
    address assetAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // USDC
uint256 depositAmount = 100 * 10**18; // wsteth with 18 decimals
    // Deploy the strategy
    strategy = new AaveLoopingStrategy(
        assetAddress,
        "Aave Looping Strategy",
        aavePoolAddress,
        swapRouterAddress
    );

    // Impersonate a user and mint tokens
    user = 0x7E458BCa9fB7C5a9e6029946F549C5f904e18dCC; // Example address
    uint256 userBalance = 1_000_000 * 10**18; 

    vm.startPrank(user);

    // Mint USDC to the user using the deal function
    deal(assetAddress, user, userBalance);

    // Verify that the balance is set correctly
    uint256 balance = MockERC20(assetAddress).balanceOf(user);
    console.log("User USDC Balance:", balance);

    // Approve the strategy to spend user's USDC
    MockERC20(assetAddress).approve(address(strategy), type(uint256).max);

        strategy.deposit(depositAmount);
    vm.stopPrank();

    assertEq(strategy.totalCollateralAmount(), depositAmount);
    assertEq(MockERC20(asset).balanceOf(user), initialBalance - depositAmount);

    vm.stopPrank();
}


// function testDeposit(assetAddress) public {
//     uint256 depositAmount = 100 * 10**6; // USDC with 6 decimals

//     vm.startPrank(user);
//     // Mint USDC to the user using the deal function
//     deal(assetAddress, user, userBalance);

//     // Verify that the balance is set correctly
//     uint256 balance = MockERC20(assetAddress).balanceOf(user);
//     console.log("User USDC Balance:", balance);

//     // Approve the strategy to spend user's USDC
//     MockERC20(assetAddress).approve(address(strategy), type(uint256).max);

//     strategy.deposit(depositAmount);
//     vm.stopPrank();

//     assertEq(strategy.totalCollateralAmount(), depositAmount);
//     assertEq(MockERC20(asset).balanceOf(user), initialBalance - depositAmount);
// }

    function testWithdraw() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawAmount = 50 ether;

        // Deposit first
        vm.startPrank(user);
        strategy.deposit(depositAmount);

        // Perform withdrawal
        strategy.withdraw(withdrawAmount);
        vm.stopPrank();

        // Assert the strategy's total collateral amount
        assertEq(strategy.totalCollateralAmount(), depositAmount - withdrawAmount);

        // Assert the Aave pool balance decreased
assertEq(aavePool.supplyBalance(address(asset)), depositAmount - withdrawAmount);

        // Assert the user's balance increased
        assertEq(asset.balanceOf(user), initialBalance - depositAmount + withdrawAmount);
    }

    function testGetRate() public {
        uint256 depositAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 supplyRate = 2 ether; // 2% supply rate
        uint256 borrowRate = 1 ether; // 1% borrow rate

        // Mock Aave rates
        aavePool.setRates(address(asset), supplyRate, borrowRate);

        // Deposit and simulate borrowing
        vm.startPrank(user);
        strategy.deposit(depositAmount);
        aavePool.simulateBorrow(address(strategy), borrowAmount);
        vm.stopPrank();

        // Calculate the expected rate
        uint256 expectedRate = (supplyRate * depositAmount - borrowRate * borrowAmount) / depositAmount;

        // Assert the rate matches the expected value
        assertEq(strategy.getRate(), expectedRate);
    }
}
