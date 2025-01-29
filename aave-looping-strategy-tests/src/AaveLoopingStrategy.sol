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
                    REQUIRED ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployFunds(uint256 _amount) internal override {
        ERC20(asset).approve(address(aavePool), _amount);
        aavePool.supply(address(asset), _amount, address(this), 0);
        totalCollateralAmount += _amount;
    }

    function _freeFunds(uint256 _amount) internal override {
        aavePool.withdraw(address(asset), _amount, address(this));
        totalCollateralAmount -= _amount;
    }

    function _harvestAndReport() internal override view returns (uint256) {
        //Not used
        return totalCollateralAmount;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deposit(uint256 amount) internal {
        ERC20(asset).approve(address(aavePool), amount);
        aavePool.supply(address(asset), amount, address(this), 0);
        totalCollateralAmount += amount;
        _executeLoop(amount);
    }

    function _withdraw(uint256 amount) internal {
        while (totalEthBorrowedAmount > 0) {
            uint256 wstETHToRepay = _calculateRepayAmount();
            aavePool.withdraw(address(asset), wstETHToRepay, address(this));
            uint256 ethReceived = _swapWstETHForETH(wstETHToRepay);
            aavePool.repay(address(0), ethReceived, 2, address(this));
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
            (, , , , , uint256 healthFactor) = aavePool.getUserAccountData(address(this));
            if (healthFactor < maxHealthFactor) {
                break;
            }
            uint256 borrowAmount = remainingCollateral / 2;
            aavePool.borrow(address(0), borrowAmount, 2, 0, address(this));
            uint256 swappedAmount = _swapETHForWstETH(borrowAmount);
            ERC20(asset).approve(address(aavePool), swappedAmount);
            aavePool.supply(address(asset), swappedAmount, address(this), 0);
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
        supplyRate = reserveData.currentLiquidityRate / 1e9;
        borrowRate = reserveData.currentVariableBorrowRate / 1e9;
    }

    function _calculateRepayAmount() internal view returns (uint256) {
        return totalEthBorrowedAmount / 2;
    }
}
