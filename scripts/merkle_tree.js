const ethers = require("ethers");
const fs = require("fs");
const {MerkleTree} = require("merkletreejs");
const keccak256 = require("keccak256");
require('dotenv').config();


let whitelist = fs.readFileSync("scripts/user_points.csv", "utf-8").split("\n");

let leaves = [];

let whitelistProofs = {
    "proofs":{}
}

for(let i = 1; i < whitelist.length; i++){
    let tokens = whitelist[i].trim().split(",");
    let address = tokens[0];
    let points = tokens[1];
    leaves.push(ethers.utils.solidityPack(["address", "uint256"], [address, points]));
    whitelistProofs["proofs"][address] = {"points":points};
}
let merkleTree = new MerkleTree(leaves, keccak256, {hashLeaves: true, sortPairs: true});
whitelistProofs["root"] = merkleTree.getHexRoot();

for(let address in whitelistProofs["proofs"]){
    let leaf = ethers.utils.solidityKeccak256(["address", "uint256"], [address, whitelistProofs["proofs"][address]["points"]]);
    let proof = merkleTree.getHexProof(leaf);
    whitelistProofs["proofs"][address]["proof"] = proof;
}

fs.writeFileSync("whitelist-proofs.json",JSON.stringify(whitelistProofs,null,"\t"),"utf-8");