// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./types/ERC20.sol";
import "./libraries/SafeMath.sol";
import "./types/Ownable.sol";
import "./libraries/EnumerableSet.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC721.sol";

contract TomSale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    event AddSaleAmount(uint256 amount);
    event Deposit(address indexed user, address indexed nft, uint256 aAmount, uint256 fAmount, uint256 tokenID);
    event Settlement();
    event Claim(address indexed user, uint256 ethAmount, uint256 cAmount);
    event ClaimReamin(address indexed account, uint256 amount);
    event AddNftToken(address account);
    event RemoveNftToken(address account);

    struct SaleInfo {
        uint256 startTime;
        uint256 endTime;
        uint256 saleRate;
        uint256 softCap;
        uint256 hardCap;
        uint256 perMinAmount;
        uint256 maxAmount;
        uint256 price;
    }


    struct UnlockInfo {
        uint256 firstRate;
        uint256 secondRate;
        uint256 thirstRate;
        uint256 secondTime;
        uint256 thirdTime;
    }

    struct UserInfo {
        uint256 actualAmount;
        uint256 faceValue;
        uint256 noDiscountAmount;
        uint256 hasClaimETH;
        uint256 hasClaimAmount;
    }

    struct PoolInfo {
        uint256 totalActualAmount;
        uint256 totalFaceValue;   
        uint256 totalSaleAmount; 
        uint256 remainAmount;
        uint8 state;
    }

    struct Cache {
        uint256 costFaceValue;
        uint256 returnAmount;
        uint256 tomAmount;
    }

    SaleInfo public saleInfo;
    UnlockInfo public unlockInfo;
    PoolInfo public poolInfo;

    EnumerableSet.AddressSet depositor;
    EnumerableSet.AddressSet nftToken;
    IERC20 public rewardToken;
    address public operator;
    uint256 public constant baseRate = 10000;
    uint256 public constant muti = 1e18;
    bool public isRemainClaim;

    mapping(address => UserInfo) public userInfo;
    mapping(address => mapping(uint256 => address)) public nftToInitDepositor;
    

    constructor(
        address rewardToken_,
        uint256 startTime_,
        uint256 endTime_
    ) {
        rewardToken = IERC20(rewardToken_);
        _initialize(startTime_, endTime_);
    }

    modifier onlyPolicy() {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        _;
    }  

    modifier notEnd() {
        require(saleInfo.endTime > block.timestamp, "has end");
        _;
    }

    function _initialize(uint256 startTime_, uint256 endTime_) internal {
        require(startTime_ > block.timestamp && endTime_ >  startTime_, "time err");
        saleInfo.startTime = startTime_;
        saleInfo.endTime = endTime_;
        saleInfo.hardCap = 100e18;
        saleInfo.softCap = 50e18;
        saleInfo.maxAmount = 2e18;
        saleInfo.perMinAmount = 0.01e18;
        saleInfo.price = 1e18;

        unlockInfo.firstRate = 4000;
        unlockInfo.secondRate = 3000;
        unlockInfo.thirstRate = 3000;
        unlockInfo.secondTime = 30 days;
        unlockInfo.thirdTime = 30 days;
    }
    

    
    function setOperator(address op) external onlyOwner {
        operator = op;
    }

    function addOrRemoveNftToken(address[] memory accounts, bool isAdd) external onlyPolicy {
        if(isAdd) {
            addNftToken(accounts);
        } else {
            removeNftToken(accounts);
        }
    }


    function addNftToken(address[] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(!nftToken.contains(accounts[i])) {
                nftToken.add(accounts[i]);
                emit AddNftToken(accounts[i]);
            }
        }
    }


    function removeNftToken(address[] memory accounts) internal  {
        for (uint256 i = 0; i < accounts.length; i++) {
            if(nftToken.contains(accounts[i])) {
                nftToken.remove(accounts[i]);
                emit RemoveNftToken(accounts[i]);
            }
        }
    }

    function setPrice(uint256 price_) external onlyPolicy {
        require(price_ > 0, "price err");
        require(price_.div(muti) <= 1e6 || muti.div(price_) <= 1e6, "price too small or big");

        saleInfo.price = price_;
    }
    

    function delyEndTime(uint256 time) external onlyPolicy notEnd {
        require(time > saleInfo.endTime, "time err");

        saleInfo.endTime = time;
    }

    function setSaleRate(uint256 rate) external onlyPolicy {
        require(rate > 0 && rate < baseRate, "rate err");
        require(poolInfo.totalActualAmount == 0, "has some deposit");

        saleInfo.saleRate = rate;
    }

    function setCap(uint256 softCap_, uint256 hardCap_) external onlyPolicy notEnd {
        require(softCap_ > 0 && hardCap_ > softCap_, "cap err");

        saleInfo.softCap = softCap_;
        saleInfo.hardCap = hardCap_;
    }

    function setSaleMinMaxAmount(uint256 min, uint256 max) external onlyPolicy notEnd {
        require(min > 0 && max > min, "set amount err");

        saleInfo.perMinAmount = min;
        saleInfo.maxAmount = max;
    }

    function setPeriod(uint256 secondTime_, uint256 thirdTime_) external onlyPolicy notEnd {
        require(secondTime_ > 0 && thirdTime_ > 0, "time err");

        unlockInfo.secondTime = secondTime_;
        unlockInfo.thirdTime = thirdTime_;
    }

    function addSaleAmount(uint256 amount)  external onlyPolicy {
        require(amount > 0, "amount err");
        require(poolInfo.state == 0, "has settlement");

        poolInfo.totalSaleAmount = poolInfo.totalSaleAmount.add(amount);
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        emit AddSaleAmount(amount);
    }



    function deposit(uint256 amount, address nft, uint256 tokenID) external payable {
        uint256 value = checkDeposit(msg.sender,  nft, amount, tokenID);
        require(msg.value == value, "value err");

        if(nftToInitDepositor[nft][tokenID] == address(0)) {
            nftToInitDepositor[nft][tokenID] == msg.sender;
        } 

        depositor.add(msg.sender);
        _deposit(amount, value, tokenID);

        emit Deposit(msg.sender, nft, amount, value, tokenID);
    }


    function checkDeposit(address user, address nft, uint256 amount, uint256 tokenID) public view returns(uint256 value) {
        require(poolInfo.totalSaleAmount > 0, "not add amount");
        require(saleInfo.startTime <= block.timestamp && block.timestamp <  saleInfo.endTime, "time err");

        if(nft != address(0) && tokenID != 0) {
            require(nft != address(0) && tokenID != 0, "nft param err");
            require(nftToken.contains(nft), "not add");
            require(IERC721(nft).ownerOf(tokenID) == user, "not owner");
            require(nftToInitDepositor[nft][tokenID] == user || nftToInitDepositor[nft][tokenID] == address(0), "init err");
            require(saleInfo.saleRate != 0, "not set rate");
            value = amount.mul(saleInfo.saleRate).div(baseRate);
        } else if (nft == address(0) && tokenID == 0){
            value = amount;
        } else {
            revert("param err");
        }
        
        require(amount >= saleInfo.perMinAmount, "too small");

        require(amount.add(userInfo[user].faceValue.add(userInfo[user].noDiscountAmount)) <= saleInfo.maxAmount, "too big");

        
        require(block.timestamp >= saleInfo.startTime && block.timestamp < saleInfo.endTime, "time err");
    }

    function _deposit(uint256 amount, uint256 value, uint256 tokenID) internal {
        if(tokenID != 0) {
            userInfo[msg.sender].actualAmount = userInfo[msg.sender].actualAmount.add(value);
            userInfo[msg.sender].faceValue = userInfo[msg.sender].faceValue.add(amount);
        } else {
            userInfo[msg.sender].noDiscountAmount = userInfo[msg.sender].noDiscountAmount.add(value);
        }

        poolInfo.totalActualAmount = poolInfo.totalActualAmount.add(value);
        poolInfo.totalFaceValue = poolInfo.totalFaceValue.add(amount);
    } 



    receive() external payable {}


    function settlement() external {
        checkSettlement();
        _settlementUser();

        emit Settlement();
    }

    function checkSettlement() public view returns(bool) {
        require(saleInfo.endTime <= block.timestamp, "not end");
        require(poolInfo.state == 0, "has settlement");

        return true;
    }

    function _settlementUser() internal {
        if(poolInfo.totalFaceValue < saleInfo.softCap) {
            poolInfo.state = 1;
        } else if(poolInfo.totalFaceValue >= saleInfo.softCap && poolInfo.totalFaceValue < saleInfo.hardCap){
            poolInfo.state = 2;   
            getRemain(poolInfo.totalFaceValue);
        } else {
            poolInfo.state = 3; 
            getRemain(saleInfo.hardCap);
        }
    }

    function getRemain(uint256 amount) internal {
        uint256 cost = saleInfo.price.mul(amount).div(muti);
        if(cost < poolInfo.totalSaleAmount) {
            poolInfo.remainAmount = poolInfo.totalSaleAmount - cost;
        }
    }


    function claim() external {
        (uint256 ethAmount, uint256 cAmount) = checkCalim(msg.sender);
        if(ethAmount > 0) {
            userInfo[msg.sender].hasClaimETH = ethAmount;
            payable(msg.sender).transfer(ethAmount);
        }

        if(cAmount > 0) {
            userInfo[msg.sender].hasClaimAmount =  userInfo[msg.sender].hasClaimAmount.add(cAmount);
            if(rewardToken.balanceOf(address(this)) < cAmount) {
                cAmount = rewardToken.balanceOf(address(this));
            }
            rewardToken.safeTransfer(msg.sender, cAmount);
        }

        emit Claim(msg.sender, ethAmount, cAmount);
    }

    function checkCalim(address user) public view returns(uint256 ethAmount, uint256 cAmount) {
        require(depositor.contains(user), "not deposit");
        require(poolInfo.state != 0, "not settlement");

        (ethAmount, cAmount) = getETHAndUnLockAmount(user);
       
        cAmount = cAmount.sub(userInfo[user].hasClaimAmount);


        require(ethAmount != 0 || cAmount != 0, "no claim");
    }

    function getETHAndUnLockAmount(address user) public view returns(uint256, uint256) {
        (uint256 eAmount,uint256 cAmount) = getETHTomAmount(user);
        if(poolInfo.state == 0) {
            return (eAmount, 0);
        }

        if(cAmount == 0) {
            return (eAmount, 0);
        }


        (uint256 sTime, uint256 tTime) = getTime();
        if(block.timestamp >= saleInfo.endTime && block.timestamp < sTime) {
            return (eAmount, cAmount.mul(unlockInfo.firstRate).div(baseRate));
    
        } else if(block.timestamp >= sTime && block.timestamp < tTime) {
            return (eAmount, cAmount.mul(unlockInfo.firstRate.add(unlockInfo.secondRate)).div(baseRate));

        } else if(block.timestamp >= tTime) {
            return (eAmount, cAmount);
        }

        return (eAmount, 0);
    }

    function getETHTomAmount(address user) public view returns(uint256 eAmount, uint256 tAmount) {
        
        (Cache memory c1, Cache memory c2) = getEstimateTomAmount(user);
        eAmount = c1.returnAmount.add(c2.returnAmount);
        tAmount = c1.tomAmount.add(c2.tomAmount);
        if(userInfo[user].hasClaimETH != 0) {
            eAmount = 0;
        }
    }

    function getEstimateTomAmount(address user) public view returns(Cache memory c1, Cache memory c2) {
        if(!depositor.contains(user)) {
            return (c1, c2);
        }

        if(poolInfo.totalFaceValue < saleInfo.softCap) {
            c1.returnAmount = userInfo[user].actualAmount;
            c2.returnAmount = userInfo[user].noDiscountAmount;
            return (c1, c2);
        }


        uint256 cost = saleInfo.price.mul(poolInfo.totalFaceValue).div(muti);
        if(cost <= poolInfo.totalSaleAmount && (poolInfo.totalFaceValue >= saleInfo.softCap && poolInfo.totalFaceValue < saleInfo.hardCap)) {
            c1.tomAmount = cost.mul(userInfo[user].faceValue).div(poolInfo.totalFaceValue);

            c2.tomAmount = cost.mul(userInfo[user].noDiscountAmount).div(poolInfo.totalFaceValue);
            return (c1, c2);
        }

        uint256 _hardCap =  saleInfo.hardCap;
        if(poolInfo.totalFaceValue >= saleInfo.softCap && poolInfo.totalFaceValue < saleInfo.hardCap) {
            _hardCap = poolInfo.totalFaceValue;
        }

        if(userInfo[user].faceValue != 0) {
            c1.costFaceValue = _hardCap.mul(userInfo[user].faceValue).div(poolInfo.totalFaceValue);
            uint256 actCost = c1.costFaceValue.mul(saleInfo.saleRate).div(baseRate);
            c1.returnAmount = userInfo[user].actualAmount.sub(actCost);
            c1.tomAmount = saleInfo.price.mul(actCost).mul(baseRate).div(saleInfo.saleRate).div(muti);
        }

        if(userInfo[user].noDiscountAmount != 0) {
            c2.costFaceValue = _hardCap.mul(userInfo[user].noDiscountAmount).div(poolInfo.totalFaceValue);
            c2.returnAmount = userInfo[user].noDiscountAmount.sub(c2.costFaceValue);
            c2.tomAmount = saleInfo.price.mul(c2.costFaceValue).div(muti);
        }
    }


    function claimReamin() external onlyPolicy {
        require(poolInfo.remainAmount > 0 && !isRemainClaim, "claim err");

        isRemainClaim = true;
        rewardToken.safeTransfer(msg.sender, poolInfo.remainAmount);

        emit ClaimReamin(msg.sender, poolInfo.remainAmount);
    }

    function getTime() public view returns(uint256 sTime, uint256 tTime) {
        sTime = saleInfo.endTime.add(unlockInfo.secondTime);
        tTime = sTime.add(unlockInfo.thirdTime);
    }

    function getCurrTime() external view returns(uint256) {
        return block.timestamp;
    }
    
    function getBlockNum() external view returns(uint256) {
        return block.number;
    }

    function getDepositorNum() external view returns(uint256) {
        return depositor.length();
    }

    function getDepositor(uint256 index) external view returns(address) {
        return depositor.at(index);
    }

    function getDepositorIn(address user) external view returns(bool) {
        return depositor.contains(user);
    }

    function getDiscount(address nft, address user) external view returns(uint256) {
        if(!nftToken.contains(nft)) {
            return 0;
        }
        if(IERC721(nft).balanceOf(user) > 0) {
            return baseRate - saleInfo.saleRate;
        }
        
        return 0;
    }

    function receivieETH(uint256 amount) external onlyPolicy {
        payable(msg.sender).transfer(amount);
    }


    function getNftTokenNum() external view returns(uint256) {
        return nftToken.length();
    }

    function getNftToken(uint256 index) external view returns(address) {
        return nftToken.at(index);
    }

    function getIsInNftToken(address account) external view returns(bool) {
        return nftToken.contains(account);
    }
    
}