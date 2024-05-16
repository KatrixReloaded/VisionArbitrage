// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";

contract FlashLoanArbitrage is IFlashLoanRecipient {
    IVault private constant vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    //@dev Uniswap V2Router02 doesn't support any testnets, using UniversalRouter instead
    // IUniswapV2Router02 private constant uniswapRouter = IUniswapV2Router02(<UniswapRouterAddress>);
    IUniswapV2Router02 private constant sushiswapRouter = IUniswapV2Router02(0xeaBcE3E74EF41FB40024a21Cc2ee2F5dDc615791);
    IUniversalRouter private constant uniswapRouter = IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);


    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external {
        vault.flashLoan(this, tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault), "Caller must be the vault");

        // Arbitrage logic: Loop through each token to execute arbitrage trades
        for (uint i = 0; i < tokens.length; i++) {
            uint amount = amounts[i];
            uint feeAmount = feeAmounts[i];
            IERC20 token = tokens[i];

            // Approve tokens for trading on Uniswap and Sushiswap
            token.approve(address(uniswapRouter), amount);
            token.approve(address(sushiswapRouter), amount);

            // Perform arbitrage trades
            address[] memory path = new address[](2);
            path[0] = address(token);
            path[1] = <OtherTokenAddress>; // Token to trade to

            uint amountOutMin = 1; // Minimum acceptable amount out, set according to slippage tolerance
            uint[] memory amountsOutUniswap = uniswapRouter.swapExactTokensForTokens(
                amount,
                amountOutMin,
                path,
                address(this),
                block.timestamp
            );

            uint amountReceived = amountsOutUniswap[1];

            // Trade back on Sushiswap
            path[0] = <OtherTokenAddress>;
            path[1] = address(token);

            uint[] memory amountsOutSushiswap = sushiswapRouter.swapExactTokensForTokens(
                amountReceived,
                amountOutMin,
                path,
                address(this),
                block.timestamp
            );

            uint finalAmountReceived = amountsOutSushiswap[1];

            // Ensure we have enough to repay the loan plus fees
            require(finalAmountReceived >= amount + feeAmount, "Arbitrage failed to cover loan and fees");

            // Repay the loan
            token.transfer(address(vault), amount + feeAmount);
        }
    }
}