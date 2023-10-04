// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract RewardsWhitelist {

    address public owner;
    mapping (uint256 => bytes32) public merkleRootByWeekNumber;

    constructor(address _owner){
        owner = _owner;
    }

    function setMerkleRoot(uint256 _weekNumber, bytes32 _merkleRoot) public {
        require(msg.sender == owner, "only owner can set merkle root");
        merkleRootByWeekNumber[_weekNumber] = _merkleRoot;
    }

    function verifyAddress(address user, uint256 points,uint256 week, bytes32[] calldata _merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user,points));
        bytes32 root = merkleRootByWeekNumber[week];
        return MerkleProof.verify(_merkleProof, root, leaf);
    }    

}