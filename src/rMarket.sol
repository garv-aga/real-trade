// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@redstone-finance/evm-connector/dist/contracts/data-services/MainDemoConsumerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {rStock} from "./rStock.sol";

/**
 * @title rMarket
 * @author mrk1tty
 * @notice This contract uses redstone oracle for pricefeed and gelato's functions to make requests to Alpaca API to buy real world stock/commodities and mint the backed token on-chain.
 * @dev This contract is not audited or rigorously tested, just a prototype. Do not use in production.
 */

contract rMarket is MainDemoConsumerBase {
    error rMarket_Insufficient_Funds();
    error rMarket_Insufficient_Tokens();
    event BuyRequest(uint256 amountOfStocks, address buyer, uint256 purchaseValue);
    event SellRequest(uint256 amountOfStocks, address seller, uint256 sellValue);

    uint256 SLIPPAGE = 102;
    IERC20 public usdt;
    rStock public rStockToken;


    mapping(address => uint256) private s_USDTBalance;

    constructor(address usdtAddr, address rStockAddr) {
        usdt = IERC20(usdtAddr);
        rStockToken = rStock(rStockAddr);
    }

    function depositUSDT(uint256 _amount) external {
        require(usdt.approve(address(this), _amount), "ApprovalDeniedOrFailed");
        bool success = usdt.transferFrom(msg.sender, address(this), _amount);
        require(success, "TransferDeniedOrFailed");
        s_USDTBalance[msg.sender] += _amount;
    } // Updates mapping for balance of ERC20

    function buyRStock(uint256 _amountOfStocks) external {
        uint256 purchaseValue = getUSDTValueOfUSD(((getStockPrice()*_amountOfStocks)*SLIPPAGE)/100);
        if(purchaseValue < s_USDTBalance[msg.sender]) {
            revert rMarket_Insufficient_Funds();
        }

        emit BuyRequest(_amountOfStocks, msg.sender, purchaseValue);
        // call function
        // emit event
        // off chain compute will call mintRstock, which will update portfolio balance and mint the tokens.

    } // checks amount of stock can be bought from price feed and calls functions

    function mintRStock(uint256 _amountOfStocks, address _buyer, uint256 _purchaseValue) external {
        s_USDTBalance[_buyer] -= _purchaseValue;
        rStockToken.mint(_buyer, _amountOfStocks);
    } // Upon event of buyStock, mints the token for user

    function sellRStock(uint256 _amountOfStocks) external {
        if(rStockToken.balanceOf(msg.sender) < _amountOfStocks) {
            revert rMarket_Insufficient_Tokens();
        }

        uint256 sellValue = getUSDTValueOfUSD(getStockPrice()*_amountOfStocks);

        emit SellRequest(_amountOfStocks, msg.sender, sellValue);
    } // emits event to sell the stock, gelato.

    function burnRStock(uint256 _amountOfStocks, address _seller, uint256 _sellValue) external {
        rStockToken.burn(_seller, _amountOfStocks);
        s_USDTBalance[_seller] += _sellValue;
    } // burns erc and updates portfolio balance

    function withdrawUSDT(uint256 _withdrawalAmount) external {
        if(_withdrawalAmount > s_USDTBalance[msg.sender]) {
            revert rMarket_Insufficient_Funds();
        }
        s_USDTBalance[msg.sender] -= _withdrawalAmount;
        usdt.transfer(msg.sender, _withdrawalAmount);
    } // Withdraws the USDT affter selling

    function getStockPrice() internal view returns (uint256) {
        return getOracleNumericValueFromTxMsg(bytes32("AAPL"));
    } // Calls oracle for price feed

    function getUSDTValueOfUSD(uint256 usdValue) internal view returns (uint256) {
        uint256 usdcValue = getOracleNumericValueFromTxMsg(bytes32("USDT"));
        return usdValue / usdcValue;
    }
}