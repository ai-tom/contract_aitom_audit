// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "./types/ERC20.sol";
import "./types/Ownable.sol";
import "./libraries/EnumerableSet.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC20Metadata.sol";

contract TomMarket is Ownable {
    event AddTomAmount(uint256 amount);
    event TransferTo(address token, address account, uint256 amount);
    event Purchase(address indexed user, uint256 cost, uint256 amount);
    event AddBuyerWhitelist(address indexed account);
    event RemoveBuyerWhitelist(address indexed account);

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;


    EnumerableSet.AddressSet buyerWhitelist;
    IERC20 public purchaseToken;
    IERC20 public tomToken;

    address public operator;
    uint256 public price;
    uint256 public limitAmount;
    uint256 public maxUserNumber = 1000;
    
    uint256 constant muti = 1e18;
    uint8 pDecimals;
    uint8 tDecimasl;
    
    struct UserInfo {
        uint256 costAmount;
        uint256 purchaseAmount;
        bool isBuy;
    }

    struct PoolState {
        uint256 totalAmount;
        uint256 withdrawAmount;
        uint256 buyerAmount;
        uint256 outAmount;
        uint256 number;
    }


    PoolState public poolState;
    mapping(address => UserInfo) public userInfo;

    constructor(
        address token,
        address tomToken_,
        uint256 price_,
        uint256 limitAmount_
    ) {
        purchaseToken = IERC20(token);
        tomToken = IERC20(tomToken_);
        pDecimals = IERC20Metadata(token).decimals();
        tDecimasl = IERC20Metadata(tomToken_).decimals();
        price = price_;
        limitAmount = limitAmount_;
    }


    modifier onlyPolicy() {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        _;
    }  



    function setOperator(address op) external onlyOwner {
        operator = op;
    }

    function setPrice(uint256 price_) external onlyPolicy {
        require(price > 0, "price err");
        price = price_;
    }

    function setLimitAmount(uint256 limitAmount_)  external onlyPolicy {
        require(limitAmount_ > 0, "limitAmount_ err");
        limitAmount = limitAmount_;
    }

    function setMaxUserNumber(uint256 newNum) external onlyPolicy {
        require(newNum > 0, "newNum err");
        maxUserNumber = newNum;
    }


    function addTomAmount(uint256 amount)  external onlyPolicy {
        require(amount > 0, "amount err");

        poolState.totalAmount = poolState.totalAmount + amount;
        tomToken.safeTransferFrom(msg.sender, address(this), amount);

        emit AddTomAmount(amount);
    }


    function transferTo(address token, address account, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount, "not enough");
        if(token == address(tomToken)) {
           poolState.withdrawAmount =  poolState.withdrawAmount + amount;
        }

        IERC20(token).safeTransfer(account, amount);
            
        emit TransferTo(token, account, amount);
    }


    function purchase() external {
        uint256 amount = checkPurchase(msg.sender);

        userInfo[msg.sender].isBuy = true;
        userInfo[msg.sender].costAmount = limitAmount;
        userInfo[msg.sender].purchaseAmount = amount;

        poolState.buyerAmount = poolState.buyerAmount + limitAmount;
        poolState.outAmount = poolState.outAmount + amount;

        purchaseToken.safeTransferFrom(msg.sender, address(this), limitAmount);
        tomToken.safeTransfer(msg.sender, amount);
        ++poolState.number;

        emit Purchase(msg.sender, limitAmount, amount);
    }

    function checkPurchase(address user) public view returns(uint256 amount) {
        require(price > 0 && limitAmount > 0, "not open purchase");
        require(buyerWhitelist.contains(user), "not in whitelist");
        require(!userInfo[user].isBuy, "has purchase");

        amount = limitAmount * (10 ** uint256(tDecimasl))/(price);
        require(tomToken.balanceOf(address(this)) >= amount, "not enough");
    }



    function addOremoveBuyerWhitelist(address[] memory accounts, bool isAdd) external onlyPolicy {
            if(isAdd) {
                addBuyerWhitelist(accounts);
            } else {
                removeBuyerWhitelist(accounts);
            }
        }

        function addBuyerWhitelist(address[] memory accounts) internal {
            for (uint256 i = 0; i < accounts.length; i++) {
                if(buyerWhitelist.length() >= maxUserNumber) {
                    return;
                }
                if(!buyerWhitelist.contains(accounts[i])) {
                    buyerWhitelist.add(accounts[i]);
                    emit AddBuyerWhitelist(accounts[i]);
                }
            }
        }


        function removeBuyerWhitelist(address[] memory accounts) internal  {
            for (uint256 i = 0; i < accounts.length; i++) {
                if(buyerWhitelist.contains(accounts[i])) {
                    buyerWhitelist.remove(accounts[i]);
                    emit RemoveBuyerWhitelist(accounts[i]);
                }
            }
        }

    function getBuyerWhitelistNum() external view returns(uint256) {
        return buyerWhitelist.length();
    }

    function getBuyerWhitelist(uint256 index) external view returns(address) {
        return buyerWhitelist.at(index);
    }

    function getIsInBuyerWhitelist(address account) external view returns(bool) {
        return buyerWhitelist.contains(account);
    }
}