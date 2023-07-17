// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;


interface IUniswapV3Pool {
    function fee() external view returns(uint24);
    function token0() external view returns(address);
    function token1() external view returns(address);
}