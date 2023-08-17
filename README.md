## Dynamic Staking Contract

### Command to setup and run the application

npm install && git init && npx hardhat init-foundry && npx hardhat compile && forge test -vvv

To deploy and verify contracts, please create an .env file with prvKey and ETHERSCAN_API_KEY

### Deployed Contract addresses

Token : https://mumbai.polygonscan.com/address/0xA3B16e8eE5b035389a7069324022bA71BE081295  \
Vault  : https://mumbai.polygonscan.com/address/0x91865e7e5319F78aca95F8FE3ACB186D00C8843F \
Proxy : https://mumbai.polygonscan.com/address/0x40E88346B4B05b2F75ab8DaC40694f0a5e8Aabcb   \
ProxyImpl (Staking) : https://mumbai.polygonscan.com/address/0x283BCAe167C295C8323e8B24E7502a9565527C2e

All contracts have been verified by using hardhat-etherscan plugin.

### Brief Overview

1. Truly decentralized, trustable and self-sustaining staking contract.
2. Uses vault() to store reward tokens that cannot be burned or transferred out of the Vault (even by owner).
3. In fixed APR, calculates rewards owed to users to make sure stakes that can't be paid out aren't accepted.
4. Calculates APR on a points basis, from 1 to 10000, where 1 is 0.01% apr and 10000 is 100% apr.
5. Caps max apr as 100% ( both in fixed and variable apr)
5. The contract supports features such as: dynamic APR, fixed APR and autocompounding


### Dynamic APR vs Fixed APR

Dynamic APR : Dynamic APR, at any point is calculated using two things, total deposits in the staking contract and total rewards in the vault. The formula used for this calculation is roughly :

            Dynamic APR =   totalRewardsInVault*multiplier/totalDeposits

Note : When deposits > rewards, the equation can return 0 and that is why we use a multiplier.  

Fixed APR: Fixed APR assures a fixed return irrespective of the total deposits or total rewards, so the formula for this kind of calculation is roughly : 
             
             Fixed APR :  UserDeposit*FixedRate (rewards for one year)

The smart contract is very well-documented and contains explanation of all methods, calculations, business logic etc.


### Autocompounding feature

There is multiple ways to implement this feature. In this implementation, compounding can be done when user
a) calls Stake b) calls Unstake c) calls compound(). There is another way to perform autocompounding, but it is a little more complicated and that is by using the formula: 

```shell
S= P(1 + R)^n , where p = priniciple, n = no of compunding periods, R = Rate of interest 
```
Here, we have to specify the autcompounding period after which the rewards will be compounded i.e 1 week, 1 month etc. In solidity, we could do something like: 

```shell
uint stake = deposits[user];
int total;
 for (i=0;i<compoundingPeriods;i++) {
		  int rewards = calculateRewards(stake);
          total = stake + rewards;
		  stake = total;
 }
```

### Optional features that can be added to the Staking contract ( based on business reqs)

0. First and foremost, owner should be definitely be multisig.
1. Minimum staking period ( cannot unstake before this period)
2. Staking Activation Period ( for ex. user would start earning rewards after a certain period)
3. Minting xTokens to user in case of stake ( just like xSushi and sushi)
4. Staking commission ( for each unstake, protocal gets small fee)
5. Pausable feature in staking, can help pause staking, but comes at gas cost for checking 
   ifPaused at every tx
6. Non- reentrant, can provide extra safety,  but comes at gas cost for every tx

### Scripts

Deploy.js : Deploy the token, vault and staking contracts \
UpgradeStaking.js : Upgrades to a new staking contract using the proxy

### Tests

Tests have been written for all three contracts using Foundry. Overall the tests are very 
comprehensive and they cover a lot of different scenarios for staking like:

1. Staking with fixed rate and variable rate
2. Staking with autocompounding
3. Checking max apr, min apr etc. to see if incoming stakes should be accepted 
4. exit pool and compound methods
5. Multiple claims, multiple deposits, claim rewards etc.

The tests are very well documented and will give a good understanding of the staking contract.
