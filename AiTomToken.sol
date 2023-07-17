// SPDX-License-Identifier: MIT

pragma solidity =0.8.19; // define specific pragma

import "./types/ERC20.sol";
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
    event SetOperator(address indexed account);
    event SetEcologicalPromoter(address indexed account);
    event SetProductMaintenance(address indexed account);
    event SetInsuredPool(address indexed account);
    event SetTaxRate(uint256 rate);
    event SetRate(uint256 eRate, uint256 pRate, uint256 iRate);
    event AddOremoveTeamlist(address[] accounts, bool isAdd);
    event AddTTeamlist(address[] accounts);
    event RemoveTeamlist(address[] accounts);
    event AddOremoveSenderWhitelist(address[] accounts, bool isAdd);
    event AddOremoveRecipientWhitelist(address[] accounts, bool isAdd);
    event Burn(address sender, uint256 amount);

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private senderWhitelist;
    EnumerableSet.AddressSet private recipientWhitelist;
    EnumerableSet.AddressSet private teamlist;

    address public ecologicalPromoter;
    address public productMaintenance;
    address public insuredPool;
    address public operator;
    uint256 public baseRate = 10000;
    uint256 public taxRate = 1000;
    uint256 public constant maxRate = 1500;

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
        require(msg.sender == owner(), "not permission");
        operator = op;
        emit SetOperator(op);
    }

    function setEcologicalPromoter(address ecologicalPromoter_) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(ecologicalPromoter_ != address(0),"address err");
        ecologicalPromoter = ecologicalPromoter_;
        emit SetEcologicalPromoter(ecologicalPromoter_);
    }

    function setProductMaintenance(address productMaintenance_) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        productMaintenance = productMaintenance_;
        emit SetProductMaintenance(productMaintenance_);
    }

    function setInsuredPool(address insuredPool_) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(insuredPool_ != address(0), "address err");
        insuredPool = insuredPool_;
        emit SetInsuredPool(insuredPool_);
    }

    function setTaxRate(uint256 rate) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(rate < baseRate && rate <= maxRate, "rate err");
        taxRate = rate;
        emit SetTaxRate(rate);
    }

    function setRate(uint256 eRate, uint256 pRate, uint256 iRate) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require((eRate + pRate+ iRate) == baseRate, "rate err");

        ecologicalPromoterRate = eRate;
        productMaintenanceRate = pRate;
        insuredPoolRate = iRate;
        emit SetRate(eRate, pRate,iRate);
    }


    function addOremoveTeamlist(address[] memory accounts, bool isAdd) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        //missing required
        if(isAdd) {
            addTTeamlist(accounts);
        } else {
            removeTeamlist(accounts);
        }
        emit AddOremoveTeamlist(accounts, isAdd);
    }

    function addTTeamlist(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(!teamlist.contains(accounts[i])) {
                teamlist.add(accounts[i]);
                emit AddTeamlist(accounts[i]);
            }
        }
        emit AddTTeamlist(accounts);
    }

    function removeTeamlist(address[] memory accounts) internal  {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(teamlist.contains(accounts[i])) {
                teamlist.remove(accounts[i]);
                emit RemoveTeamlist(accounts[i]);
            }
        }
        emit RemoveTeamlist(accounts);
    }


    function addOremoveSenderWhitelist(address[] memory accounts, bool isAdd) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        if(isAdd) {
            addSenderWhitelist(accounts);
        } else {
            removeSenderWhitelist(accounts);
        }
        emit AddOremoveSenderWhitelist(accounts, isAdd);
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
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        if(isAdd) {
            addRecipientWhitelist(accounts);
        } else {
            removeRecipientWhitelist(accounts);
        }
        emit AddOremoveRecipientWhitelist(accounts, isAdd);
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
            uint256 value = amount * taxRate / baseRate;
            uint256 eAmount = value * ecologicalPromoterRate / baseRate;
            uint256 pAmount = value * productMaintenanceRate / baseRate;
            uint256 iAmount = value - eAmount - pAmount;

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
                    productBurn = productBurn + pAmount;
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
        emit Burn(msg.sender, amount);
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