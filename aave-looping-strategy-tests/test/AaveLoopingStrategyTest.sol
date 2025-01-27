// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;

import "forge-std/Test.sol";
import "../src/AaveLoopingStrategy.sol";
import {MockERC20} from "../lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {MockAavePool} from "./mocks/MockAavePool.sol";
import {MockSwapRouter} from "./mocks/MockSwapRouter.sol";

contract AaveLoopingStrategyTest is Test {
    AaveLoopingStrategy private strategy;
    MockERC20 private asset;
    MockAavePool private aavePool;
    MockSwapRouter private swapRouter;

    address private user = address(0x1234);
    uint256 private initialBalance = 1_000_000 ether;

    function setUp() public {
        // Deploy mock contracts
        asset = new MockERC20("Mock Asset", "MCK", 18);
        aavePool = new MockAavePool();
        swapRouter = new MockSwapRouter();

        // Mint initial balance to the user
        asset.mint(user, initialBalance);

        // Deploy the strategy
        strategy = new AaveLoopingStrategy(
            address(asset),
            "Aave Looping Strategy",
            address(aavePool),
            address(swapRouter)
        );

        // Approve strategy to spend user’s asset
        vm.startPrank(user);
        asset.approve(address(strategy), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 depositAmount = 100 ether;

        // Perform deposit
        vm.startPrank(user);
        strategy.deposit(depositAmount);
        vm.stopPrank();

        // Assert the strategy's total collateral amount
        assertEq(strategy.totalCollateralAmount(), depositAmount);

        // Assert the Aave pool received the asset
        assertEq(aavePool.supplyBalance(address(asset), address(strategy)), depositAmount);

        // Assert the user's balance decreased
        assertEq(asset.balanceOf(user), initialBalance - depositAmount);
    }

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
        assertEq(aavePool.supplyBalance(address(asset), address(strategy)), depositAmount - withdrawAmount);

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
