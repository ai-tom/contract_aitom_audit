// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "./ERC721.sol";
import "./ERC721Enumerable.sol";
import "./Ownable.sol";
import "../libraries/Strings.sol";

import "./ContentMixin.sol";
import "./NativeMetaTransaction.sol";
import "../libraries/EnumerableSet.sol";


abstract contract ERC721Tradable is ContextMixin, ERC721Enumerable, NativeMetaTransaction, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    event AddMinter(address newMinter);
    event RemoveMinter(address _minter);
    event MintTo(address _to, uint256 _tokenID);

    uint256 _currentTokenId = 0;
    uint256 public num = 3;

    EnumerableSet.AddressSet isMinter;
    

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol)  {
        _initializeEIP712(_name);
    }

    function addMinter(address newMinter) onlyOwner public returns(bool) {
        require(!isMinter.contains(newMinter), "has exist");
        isMinter.add(newMinter);
        emit AddMinter(newMinter);
        return true;
    }

    function removeMinter(address _minter) onlyOwner public returns(bool) {
        require(isMinter.contains(_minter), "not exist");
        isMinter.remove(_minter);
        emit RemoveMinter(_minter);
        return true;
    }
    
    /**
     * @dev Mints a token to an address with a tokenURI.
     * @param _to address of the future owner of the token
     */
    function mintTo(address _to) public returns(uint256) {
        require(isMinter.contains(msg.sender) || msg.sender == owner(), "not minter");

        uint256 newTokenId = _getNextTokenId();
        
        _mint(_to, newTokenId);
        _incrementTokenId();
        
        emit MintTo(_to, newTokenId);
        return newTokenId;
    }

    function burn(uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }
    

    /**
     * @dev calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        _currentTokenId++;
    }

    function baseTokenURI() virtual public view returns (string memory);
    

    function setNum(uint256 newNum) external onlyOwner {
        require(newNum > 0, "newNum err");

        num = newNum;
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        if(_tokenId == 0) {
            return baseTokenURI();
        }
        uint256 id = _tokenId % num;
        if(id == 0) {
            id = num;
        }
        return string(abi.encodePacked(baseTokenURI(), Strings.toString(id), ".json"));
     
    }

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    function getMinterLength() external view returns(uint256) {
        return isMinter.length();
    }

    function getMinter(uint256 index) external view returns(address) {
        return isMinter.at(index);
    }

    function getContains(address minter) external view returns(bool) {
        return isMinter.contains(minter);
    }

}
