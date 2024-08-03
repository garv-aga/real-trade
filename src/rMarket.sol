// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@redstone-finance/evm-connector/dist/contracts/data-services/StocksDemoConsumerBase.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title rMarket
 * @author mrk1tty
 * @notice This contract uses gelato's functions to get market related updates and to make requests to Alpaca API to buy real world stock/commodities and mint the backed token on-chain.
 * @dev This contract is not audited or rigorously tested, just a prototype. Do not use in production.
 */

contract rMarket is StocksDemoConsumerBase, ERC20, Pausable {
    error rMarket_Insufficient_Funds();
    error rMarket_Insufficient_Tokens();
    event BuyRequest(uint256 amountOfStocks, address buyer, uint256 purchaseValue);
    event SellRequest(uint256 amountOfStocks, address seller, uint256 sellValue);

    uint256 SLIPPAGE = 102;
    uint256 stockValue;
    uint256 usdtValue;
    ERC20 public usdt;
    address gelatoTrade;
    address gelatoUpdate;
    address owner;

    mapping(address => uint256) private s_USDTBalance;

    modifier whenMarketOpen {
        require(!paused(), "Market is Closed");
        _;
    }

    modifier onlyGelatoTrade {
        require(msg.sender == gelatoTrade, "Not Authorized");
        _;
    }

    modifier onlyGelatoUpdate {
        require(msg.sender == gelatoUpdate, "Not Authorized");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }


    constructor(address _usdtAddr, string memory name, string memory symbol) ERC20(name, symbol) {
        usdt = ERC20(_usdtAddr);
    }

    function depositUSDT(uint256 _amount) external {
        require(usdt.approve(address(this), _amount), "ApprovalDeniedOrFailed");
        bool success = usdt.transferFrom(msg.sender, address(this), _amount);
        require(success, "TransferDeniedOrFailed");
        s_USDTBalance[msg.sender] += _amount;
    } // Updates mapping for balance of ERC20

    function buyRStock(uint256 _amountOfStocks) external whenMarketOpen {
        uint256 purchaseValue = getUSDTValueOfUSD(((stockValue*_amountOfStocks)*SLIPPAGE)/100);
        if(purchaseValue < s_USDTBalance[msg.sender]) {
            revert rMarket_Insufficient_Funds();
        }
        emit BuyRequest(_amountOfStocks, msg.sender, purchaseValue);
    } // checks amount of stock can be bought from price feed and calls functions

    function mintRStock(uint256 _amountOfStocks, address _buyer, uint256 _purchaseValue) external /*onlyGelatoTrade*/ {
        s_USDTBalance[_buyer] -= _purchaseValue;
        _mint(_buyer, _amountOfStocks);
    } // Upon event of buyStock, mints the token for user

    function sellRStock(uint256 _amountOfStocks) external whenMarketOpen {
        if(balanceOf(msg.sender) < _amountOfStocks) {
            revert rMarket_Insufficient_Tokens();
        }

        uint256 sellValue = getUSDTValueOfUSD(stockValue*_amountOfStocks);
        emit SellRequest(_amountOfStocks, msg.sender, sellValue);
    } // emits event to sell the stock, gelato.

    function burnRStock(uint256 _amountOfStocks, address _seller, uint256 _sellValue) external /*onlyGelatoTrade*/ {
        s_USDTBalance[_seller] += _sellValue;
        _burn(_seller, _amountOfStocks);
    } // burns erc and updates portfolio balance

    function withdrawUSDT(uint256 _withdrawalAmount) external {
        if(_withdrawalAmount > s_USDTBalance[msg.sender]) {
            revert rMarket_Insufficient_Funds();
        }
        s_USDTBalance[msg.sender] -= _withdrawalAmount;
        usdt.transfer(msg.sender, _withdrawalAmount);
    } // Withdraws the USDT affter selling

    function getUSDTValueOfUSD(uint256 usdValue) internal view returns (uint256) {
        return usdValue / usdtValue;
    }

    function updateMarketData(bool _isOpen, uint256 _stockValue, uint256 _usdtValue) external /**OnlyGelatoUpdate */ {
        stockValue = _stockValue;
        usdtValue = _usdtValue;
        if(_isOpen) {
            _unpause();
        }
        else {
            _pause();
        }
    }

    function setGelato(address _gelatoTrade, address _gelatoUpdate) external onlyOwner {
        gelatoTrade = _gelatoTrade;
        gelatoUpdate = _gelatoUpdate;
    }
}