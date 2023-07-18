// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.12;

interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);
    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

    function getMoneyBack() external;
    //
    function owner() external returns(address);

    function round() external view returns(uint256);

    function changeMerkleRoot(bytes32 _merkleRoot) external returns(uint256);

    function lock() external view returns(bool);

    function pause() external;

    function start() external;

    function receiveRewardCoin(uint256 amount) external;

    event Pause(uint256 round);

    event Start(uint256 round);

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 round,uint256 index, address account, uint256 amount);
}