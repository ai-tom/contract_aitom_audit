// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;
pragma experimental ABIEncoderV2;

import "./types/Ownable.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./libraries/ReentrancyGuard.sol";

contract SwapToken is Ownable, ReentrancyGuard {
    event AiTomSwapUsdt(address indexed user, uint256 amount, uint256 value);
    event SwapExactInputSingle(uint256 amount);
    event SetTomTrgAmount(uint256 amount);
    event SetAddV3Pool(IUniswapV3Pool lpToken);
    event SetTirgger(address tirgger);
    event SetOperator(address op);

    using SafeERC20 for IERC20;

    ISwapRouter public immutable swapRouter;
    IUniswapV3Pool public lpToken;
    address public immutable tomToken;
    address public immutable USDT;
    address public operator;
    address public tirgger;

    uint256 public tomTrgAmount = 100e18;
    uint256 public useTomAmount;
    uint256 public swapUsdt;
    uint256 public totalBurn;
    uint256 public totalSwapUsdt;


    struct UserInfo {
        uint256 costTom;
        uint256 getUsdt;
    }
    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256) public transferAmount;

    
    constructor(
        ISwapRouter swapRouter_,
        address tomToken_,
        address usdt
    ) {
        swapRouter = swapRouter_;
        tomToken = tomToken_;
        USDT = usdt;
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

    
    function setTirgger(address tirgger_) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        tirgger = tirgger_;
        emit SetTirgger(tirgger_);
    }

    function setAddV3Pool(IUniswapV3Pool lpToken_) external  onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(
            (lpToken_.token0() == tomToken || lpToken_.token0() == USDT) &&
            (lpToken_.token1() == tomToken || lpToken_.token1() == USDT),
            "lpToken err"
        );


        lpToken = lpToken_;
        emit SetAddV3Pool(lpToken_);
    }

    function setTomTrgAmount(uint256 amount) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(amount > 0, "amount err");
        tomTrgAmount = amount;
        emit SetTomTrgAmount(amount);
    }

    function swapExactInputSingle() external returns (uint256 amountOut) {
        validate(msg.sender);
        uint256 amount = IERC20(tomToken).balanceOf(address(this));
        IERC20(tomToken).safeApprove(address(swapRouter), amount);

        uint256 _deadline =  block.timestamp + 3600;
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tomToken,
                tokenOut: USDT,
                fee: lpToken.fee(),
                recipient: address(this),
                deadline:_deadline,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });



        amountOut = swapRouter.exactInputSingle(params);
        useTomAmount = useTomAmount + amount;
        swapUsdt = swapUsdt + amountOut;
        emit SwapExactInputSingle(amountOut);
    }

    function validate(address tirgger_) public view returns(bool) {
        require(IERC20(tomToken).balanceOf(address(this)) >= tomTrgAmount, "amount err");
        require(
            tirgger_ == operator || 
            tirgger_ == owner() ||
            tirgger_ == tirgger, 
            "not permission"
        );
        require(address(lpToken) != address(0), "lpToken err");

        return true;
    }

   event TransferTo(address indexed token, address indexed account, uint256 amount);
    function transferTo(address token, address account, uint256 amount) external onlyPolicy {
        require(
            msg.sender == operator || msg.sender == owner(), 
            "not permission"
        );
        require(IERC20(token).balanceOf(address(this)) >= amount, "not enough");
        transferAmount[token] = transferAmount[token] + amount;
        IERC20(token).safeTransfer(account, amount);
            
        emit TransferTo(token, account, amount);
    }

    function getContractBalance(address token) public view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getUserBalance(address token, address user)  public view returns(uint256) {
        return IERC20(token).balanceOf(user);
    }

    function getTokenTotalSupply(address token) public view returns(uint256) {
         return IERC20(token).totalSupply();
    }



    function aiTomSwapUsdt(uint256 amount) external nonReentrant {
        uint256 value = checkSwap(msg.sender, amount);

        totalBurn = totalBurn + amount;
        totalSwapUsdt = totalSwapUsdt + value;
        userInfo[msg.sender].costTom = userInfo[msg.sender].costTom + amount;
        userInfo[msg.sender].getUsdt = userInfo[msg.sender].getUsdt + value;

        IERC20(tomToken).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(tomToken).burn(amount);
        IERC20(USDT).safeTransfer(msg.sender, value);

        emit AiTomSwapUsdt(msg.sender, amount, value);  
    }

    function checkSwap(address user, uint256 amount) public view returns(uint256) {
        uint256 userTom = getUserBalance(tomToken, user);
        require(userTom >= amount && amount > 0, "amount err");
        uint256 total = getTokenTotalSupply(tomToken);
        uint256 uValue = getContractBalance(USDT);
        require(total > 0 && uValue > 0, "swap err");
        uint256 value = amount * uValue / total;

        return value;
    }

    function getUserCanSwap(address user) external view returns(uint256, uint256) {
        uint256 total = getTokenTotalSupply(tomToken);
        uint256 uValue = getContractBalance(USDT);
        uint256 userTom = getUserBalance(tomToken, user);
        if(total == 0 || uValue == 0 || userTom == 0) {
            return (0, 0);
        }

        uint256 value = userTom * uValue / total;
        return (userTom, value);
    }
}