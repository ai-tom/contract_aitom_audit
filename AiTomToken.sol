// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./types/ERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/EnumerableSet.sol";
import "./types/Ownable.sol";

contract AiTomToken is ERC20, Ownable {  
    event TomTransfer(
        address indexed sender, 
        address indexed recipient, 
        uint256 amount, 
        uint256 eAmount, 
        uint256 pAmount, 
        uint256 iAmount,
        uint256 burnAmount
    );
    
    
    event AddSenderWhitelist(address indexed account);
    event RemoveSenderWhitelist(address indexed account);
    event AddRecipientWhitelist(address indexed account);
    event RemoveRecipientWhitelist(address indexed account);
    event AddTeamlist(address indexed account);
    event RemoveTeamlist(address indexed account);

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet senderWhitelist;
    EnumerableSet.AddressSet recipientWhitelist;
    EnumerableSet.AddressSet teamlist;

    address public ecologicalPromoter;
    address public productMaintenance;
    address public insuredPool;
    address public operator;
    uint256 public baseRate = 10000;
    uint256 public taxRate = 1000;

    uint256 public ecologicalPromoterRate = 3000;
    uint256 public productMaintenanceRate = 3000;
    uint256 public insuredPoolRate = 4000;
    uint256 public productBurn;

    constructor(
        string memory name_, 
        string memory symbol_,
        uint256 amount_
    )ERC20(name_, symbol_) {
        _mint(msg.sender, amount_);
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

    function setEcologicalPromoter(address ecologicalPromoter_) external onlyPolicy {
        require(ecologicalPromoter_ != address(0),"address err");
        ecologicalPromoter = ecologicalPromoter_;
    }

    function setProductMaintenance(address productMaintenance_) external onlyPolicy {
        productMaintenance = productMaintenance_;
    }

    function setInsuredPool(address insuredPool_) external onlyPolicy {
        require(insuredPool_ != address(0), "address err");
        insuredPool = insuredPool_;
    }

    function setTaxRate(uint256 rate) external onlyPolicy {
        require(rate < baseRate, "rate err");
        taxRate = rate;
    }

    function setRate(uint256 eRate, uint256 pRate, uint256 iRate) external onlyPolicy {
        require(eRate.add(pRate).add(iRate) == baseRate, "rate err");

        ecologicalPromoterRate = eRate;
        productMaintenanceRate = pRate;
        insuredPoolRate = iRate;
    }


    function addOremoveTeamlist(address[] memory accounts, bool isAdd) external onlyPolicy {
        if(isAdd) {
            addTTeamlist(accounts);
        } else {
            removeTeamlist(accounts);
        }
    }

    function addTTeamlist(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(!teamlist.contains(accounts[i])) {
                teamlist.add(accounts[i]);
                emit AddTeamlist(accounts[i]);
            }
        }
    }

    function removeTeamlist(address[] memory accounts) internal  {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(teamlist.contains(accounts[i])) {
                teamlist.remove(accounts[i]);
                emit RemoveTeamlist(accounts[i]);
            }
        }
    }


    function addOremoveSenderWhitelist(address[] memory accounts, bool isAdd) external onlyPolicy {
        if(isAdd) {
            addSenderWhitelist(accounts);
        } else {
            removeSenderWhitelist(accounts);
        }
    }

    function addSenderWhitelist(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(!senderWhitelist.contains(accounts[i])) {
                senderWhitelist.add(accounts[i]);
                emit AddSenderWhitelist(accounts[i]);
            }
        }
    }


    function removeSenderWhitelist(address[] memory accounts) internal  {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(senderWhitelist.contains(accounts[i])) {
                senderWhitelist.remove(accounts[i]);
                emit RemoveSenderWhitelist(accounts[i]);
            }
        }
    }



    function addOremoveRecipientWhitelist(address[] memory accounts, bool isAdd) external onlyPolicy {
        if(isAdd) {
            addRecipientWhitelist(accounts);
        } else {
            removeRecipientWhitelist(accounts);
        }
    }

    function addRecipientWhitelist(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(!recipientWhitelist.contains(accounts[i])) {
                recipientWhitelist.add(accounts[i]);
                emit AddRecipientWhitelist(accounts[i]);
            }
        }
    }


    function removeRecipientWhitelist(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(recipientWhitelist.contains(accounts[i])) {
                recipientWhitelist.remove(accounts[i]);
                emit RemoveRecipientWhitelist(accounts[i]);
            }
        }
    }



    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _tomTransfer(_msgSender(), to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _tomTransfer(sender, recipient, amount);
    }
 
   
    function _tomTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(teamlist.contains(sender) || teamlist.contains(recipient)) {
            _transfer(sender, recipient, amount);
        } else if(
            (senderWhitelist.contains(sender) || recipientWhitelist.contains(recipient)) && 
            taxRate != 0)
        {
            uint256 value = amount.mul(taxRate).div(baseRate);
            uint256 eAmount = value.mul(ecologicalPromoterRate).div(baseRate);
            uint256 pAmount = value.mul(productMaintenanceRate).div(baseRate);
            uint256 iAmount = value.sub(eAmount).sub(pAmount);

            _transfer(sender, recipient, amount);


            if(eAmount > 0) {            
                _transfer(sender, ecologicalPromoter, eAmount);
            }


            if(iAmount > 0) {
                _transfer(sender, insuredPool, iAmount);
            }

            if(pAmount > 0) {
                if(productMaintenance != address(0)) {
                    _transfer(sender, productMaintenance, pAmount);
                } else {
                    _transfer(sender, address(this), pAmount);
                    productBurn = productBurn.add(pAmount);
                    _burn(address(this), pAmount);
                }
            }

            if(productMaintenance != address(0)) {
                emit TomTransfer(sender, recipient, amount, eAmount, pAmount, iAmount, 0);
            } else {
                emit TomTransfer(sender, recipient, amount, eAmount, 0, iAmount, pAmount);
            }

        } else {
            _transfer(sender, recipient, amount);
        }

        return true;
    }


    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }
    
    function getSenderWhitelistNum() external view returns(uint256) {
        return senderWhitelist.length();
    }

    function getSenderWhitelist(uint256 index) external view returns(address) {
        return senderWhitelist.at(index);
    }

    function getIsInSenderWhitelist(address account) external view returns(bool) {
        return senderWhitelist.contains(account);
    }


    function getRecipientWhitelistNum() external view returns(uint256) {
        return recipientWhitelist.length();
    }

    function getRecipientWhitelist(uint256 index) external view returns(address) {
        return recipientWhitelist.at(index);
    }

    function getIsInRecipientWhitelist(address account) external view returns(bool) {
        return recipientWhitelist.contains(account);
    }


    function getTeamlistNum() external view returns(uint256) {
        return teamlist.length();
    }

    function getTeamlist(uint256 index) external view returns(address) {
        return teamlist.at(index);
    }

    function getIsInTeamlist(address account) external view returns(bool) {
        return teamlist.contains(account);
    }

}