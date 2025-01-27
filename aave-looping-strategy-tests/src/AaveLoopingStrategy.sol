// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/contracts/interfaces/ISwapRouter.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import {BaseStrategy} from "./BaseStrategy.sol";

/**
 * @title AaveLoopingStrategy
 * @notice Implements a looping strategy using AAVE and Uniswap for YieldNest.
 */
contract AaveLoopingStrategy is BaseStrategy {
    using Math for uint256;
    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoopExecuted(uint256 borrowedAmount, uint256 swappedAmount);
    event WithdrawUnwind(uint256 debtRepaid, uint256 collateralWithdrawn);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ISwapRouter public immutable swapRouter;
    IPool public immutable aavePool;

    uint256 public maxHealthFactor = 1.1 ether;
    uint256 public minHealthFactor = 1.05 ether;

    uint256 public totalCollateralAmount;
    uint256 public totalEthBorrowedAmount;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _asset, string memory _name, address _aavePool, address _swapRouter)
        BaseStrategy(_asset, _name)
    {
        swapRouter = ISwapRouter(_swapRouter);
        aavePool = IPool(_aavePool);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        _deposit(amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        _withdraw(amount);
        ERC20(asset).safeTransfer(msg.sender, amount);
    }

    function getRate() external view returns (uint256) {
        // Fetch real-time AAVE lending and borrowing rates
        (uint256 supplyRate, uint256 borrowRate) = _getAaveRates();

        // Calculate the rate based on total collateral and borrowed amounts
        if (totalCollateralAmount == 0 || totalEthBorrowedAmount == 0) {
            return 0;
        }

        uint256 netRate = (supplyRate * totalCollateralAmount - borrowRate * totalEthBorrowedAmount) / totalCollateralAmount;
        return netRate;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deposit(uint256 amount) internal {
        // Approve AAVE Pool to spend asset
        ERC20(asset).safeApprove(address(aavePool), amount);

        // Supply asset to AAVE
        aavePool.supply(address(asset), amount, address(this), 0);

        // Update storage
        totalCollateralAmount += amount;

        // Execute looping logic
        _executeLoop(amount);
    }

    function _withdraw(uint256 amount) internal {
        // Unwind positions by repaying debt and withdrawing collateral
        while (totalEthBorrowedAmount > 0) {
            uint256 wstETHToRepay = _calculateRepayAmount();

            // Withdraw collateral from AAVE
            aavePool.withdraw(address(asset), wstETHToRepay, address(this));

            // Swap collateral to ETH and repay debt
            uint256 ethReceived = _swapWstETHForETH(wstETHToRepay);
            aavePool.repay(address(0), ethReceived, 2, address(this));

            // Update storage
            totalCollateralAmount -= wstETHToRepay;
            totalEthBorrowedAmount -= ethReceived;

            emit WithdrawUnwind(ethReceived, wstETHToRepay);
        }

        require(totalCollateralAmount >= amount, "Insufficient collateral");
        aavePool.withdraw(address(asset), amount, address(this));
        totalCollateralAmount -= amount;
    }

    function _executeLoop(uint256 initialAmount) internal {
        uint256 remainingCollateral = initialAmount;

        while (true) {
            // Get current health factor
            (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(address(this));

            if (healthFactor < maxHealthFactor) {
                break; // Stop looping to avoid liquidation risk
            }

            // Borrow ETH against wstETH collateral
            uint256 borrowAmount = remainingCollateral / 2; // Borrow 50% of collateral value
            aavePool.borrow(address(0), borrowAmount, 2, 0, address(this));

            // Swap borrowed ETH for more wstETH
            uint256 swappedAmount = _swapETHForWstETH(borrowAmount);

            // Approve and supply the new wstETH
            ERC20(asset).safeApprove(address(aavePool), swappedAmount);
            aavePool.supply(address(asset), swappedAmount, address(this), 0);

            // Update storage
            totalCollateralAmount += swappedAmount;
            totalEthBorrowedAmount += borrowAmount;

            emit LoopExecuted(borrowAmount, swappedAmount);

            remainingCollateral = swappedAmount;
        }
    }

    function _swapETHForWstETH(uint256 ethAmount) internal returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(0),
            tokenOut: address(asset),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: ethAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    function _swapWstETHForETH(uint256 wstETHAmount) internal returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(asset),
            tokenOut: address(0),
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: wstETHAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    function _getAaveRates() internal view returns (uint256 supplyRate, uint256 borrowRate) {
        DataTypes.ReserveData memory reserveData = aavePool.getReserveData(address(asset));

        // Convert rates from Ray (1e27) to Wad (1e18)
        supplyRate = reserveData.currentLiquidityRate / 1e9;
        borrowRate = reserveData.currentVariableBorrowRate / 1e9;
    }

    function _calculateRepayAmount() internal view returns (uint256) {
        return totalEthBorrowedAmount / 2; // Example logic, adjust as needed
    }
}
