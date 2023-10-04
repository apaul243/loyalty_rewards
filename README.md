### RewardsWhitelist.sol

1. Input all data in form of (userWalletAddress, points) in scripts/user_points.csv
2. Run node merkle_tree.js which will create & store merkleRoot and all merkle proofs in whitelist-proofs.json
3. Commit the merkle root in RewardsWhitelist.sol by calling setMerkleRoot(uint256 _weekNumber, bytes32 _merkleRoot)
4. User can call verifyAddress for whitelist verification.

### RewardsLottery.sol

1. Create a subscription at : https://vrf.chain.link/mumbai/new 
1. Deploy the contract with your subcriptionId and network specific details (vrfCoordinator & keyHash)
3. Go to : https://vrf.chain.link/mumbai/{subscriptionId} and add the contract as a consumer.
4. For requesting random numbers, call: function requestRandomWords(uint32 num_words,uint32 callback_gas_limit).
Here, callback_gas_limit is the gas specified for post-fetching random no ops in fulfillRandomWords(). Max limit is 2.5 mil . Max limit for no of words is 500
5. Callback_gas_limit might prevent from doing a lot of operations specially when no_of_words is high
