// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

import "./interface/IERC20.sol";
import "./lib/MerkleProof.sol";
import "./interface/IMerkleDistributor.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/SafeMath.sol";

contract MerkleDistributor is IMerkleDistributor, ReentrancyGuard, IERC20 {
    address public immutable override token;
    address public override owner;
    bytes32 public override merkleRoot;
    bool public override lock;
    uint256 public override round;

    event Stake(address indexed account,  uint256 tokenAmount);
    event Unstake(address indexed account, uint256 tokenAmount);

    using SafeMath for uint256;

    uint256 public limitBlocksNumber;

    IERC20 stakeToken;
    mapping(address => UserStakeInfo) public userStakes;
    uint256 public totalStake;
    uint256 public totalInRewardCoin;
    uint256 public totalClaimedAmount;
    struct UserStakeInfo{
        uint256 stakeAmount;
        uint256 lastStakeHeight;
    }

    mapping(address => bool) _isOperator;
    // This is a packed array of booleans.
    mapping(uint256=>mapping(uint256 => uint256)) private claimedBitMap;
    string public name = 'AITomStake_LP';
    string public symbol = 'AITOM_LP';
    uint8 public decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;


    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor( address _stakeTokenAddr, address _rewardTokenAddr, string memory _name, string memory _symbol, uint8 _decimals) public {
        stakeToken = IERC20(_stakeTokenAddr);
        token = _rewardTokenAddr;
        owner = msg.sender;
        lock = false;
        limitBlocksNumber = 100;
        totalSupply = 0;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint value) external override {
        revert("not support");
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address sender, address spender, uint value) private {
        allowance[sender][spender] = value;
        emit Approval(sender, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external override returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    modifier isOwner(){
        require(msg.sender == owner,"forbidden");
        _;
    }

    modifier isLock(){
        require(lock == true,"lock error");
        _;
    }

    modifier isUnLock(){
        require(lock == false,"lock error");
        _;
    }

    modifier isPermission() {
        require(isOperator(msg.sender), "not operator");
        _;
    }

    function isOperator(address _account) public view returns(bool) {
        if(_isOperator[_account] || _account == owner) {
            return true;
        }
        return false;
    }

    function addOrRemoveOpreator(address _operator, bool _isAdd) public isOwner {
        _isOperator[_operator] = _isAdd;
    }

    function getMoneyBack() public override isOwner(){
        IERC20(token).transfer(owner, IERC20(token).balanceOf(address(this)));
    }

    function pause() public override isUnLock() isPermission(){
        lock = true;
        emit Pause(round);
    }

    function start() public override isLock() isPermission(){
        lock = false;
        emit Start(round);
    }

    function changeMerkleRoot(bytes32 _merkleRoot) public override isLock() isPermission() returns(uint256){
        merkleRoot = _merkleRoot;
        return round++;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[round][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[round][claimedWordIndex] = claimedBitMap[round][claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override isUnLock(){
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
        require(IERC20(token).transfer(account, amount), 'MerkleDistributor: Transfer failed.');
        totalClaimedAmount = totalClaimedAmount.add(amount);
        emit Claimed(round,index, account, amount);
    }

    function getNodeHash(uint256 index, address account, uint256 amount) pure external returns (bytes32){
        return keccak256(abi.encodePacked(index, account, amount));
    }

    function configLimtBlockNumber(uint256 _limitBlocksNumber) isOwner external{
        limitBlocksNumber = _limitBlocksNumber;
    }

    function stake(uint256 amount) external {
        UserStakeInfo storage userStake  = userStakes[msg.sender];
        stakeToken.transferFrom(msg.sender, address(this), amount);
        userStake.lastStakeHeight = block.number;
        userStake.stakeAmount = userStake.stakeAmount.add(amount);
        totalStake = totalStake.add(amount);
        emit Stake(msg.sender, amount);
        _mint(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        UserStakeInfo storage userStake  = userStakes[msg.sender];
        require(userStake.stakeAmount >= amount, "not enough stake amount");
        require(userStake.lastStakeHeight + limitBlocksNumber <= block.number, "stake time too short");
        _burn(msg.sender, amount);
        userStake.stakeAmount = userStake.stakeAmount.sub(amount);
        stakeToken.transfer(msg.sender, amount);
        totalStake = totalStake.sub(amount);
        emit Unstake(msg.sender, amount);
    }

    function receiveRewardCoin(uint256 amount) external override{
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        totalInRewardCoin = totalInRewardCoin.add(amount);
    }
}