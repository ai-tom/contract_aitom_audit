// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./types/ERC20.sol";
import "./types/MinterOwned.sol";
import "./libraries/SafeMath.sol";

contract TestToken is ERC20, MinterOwned {
  using SafeMath for uint;
  

  constructor (string memory name, string memory symbol, uint256 amount) 
     
    ERC20(name, symbol) 
{
      _mint(msg.sender, amount);
  }

    function mint(address account_, uint256 amount_) external  onlyMinter() {
        _mint(account_, amount_);
    }


    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }
}