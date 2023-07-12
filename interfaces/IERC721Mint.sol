
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";

interface IERC721Mint is IERC721 {
    function mintTo(address _to) external returns(uint256);
    function burn(uint256 tokenId) external;
    function getCurrentID() external view returns(uint256);
    function getOwner(uint256 tokenId) external view returns (address);
}