// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import {Staking} from "../contracts/Staking.sol";
import "../contracts/Vault.sol";
import "../contracts/TestToken.sol";

contract dynamicStakingTest is Test {
    TestToken public token;
    Vault public vault;
    Staking public staking;
    address owner = makeAddr("owner");
    address john = makeAddr("john");
    address kelly = makeAddr("kelly");
    uint yearSeconds = 31536000;

    /* For the testing, we use time increments in factors of yearSeconds i.e yearSeconds/4, yearSeconds/2 etc. */

    function setUp() public {
        vm.startPrank(owner);
        /* Deploy Token, Vault and staking contracts */
        token = new TestToken();
        vault = new Vault(address(token));
        staking = new Staking(
            address(token),
            address(token),
            address(vault),
            0,
            false
        );
        /* Set staking contract in the vault contract */
        vault.setStakingContract(address(staking));
        /* Mint 100k tokens to john and kelly, 10k tokens to vault */
        token.mint(john, 100000 * 10 ** 18);
        token.mint(kelly, 100000 * 10 ** 18);
        token.mint(owner, 500000 * 10 ** 18);
        token.mint(address(vault), 10000 * 10 ** 18);
        token.approve(address(vault), 500000 * 10 ** 18);
        vm.stopPrank();
        /*Giving necesarry allowanes */
        vm.prank(john);
        token.approve(address(staking), 100000 * 10 ** 18);
        vm.prank(kelly);
        token.approve(address(staking), 100000 * 10 ** 18);
    }

    /* Testing   a) Let's say John stakes 2k tokens for one year
     *           b) Even though vault has 10k rewards, john will only get 2k since rewards
     *              are capped at a max of 100%.
     */
    function test_checkingMaxAPRCap() public {
        vm.prank(john);
        staking.stake(2000 * 10 ** 18);
        vm.warp(block.timestamp + yearSeconds); // advancing by one year
        vm.prank(john);
        uint rewards = staking.claim();
        assertEq(rewards, 2000 * 10 ** 18);
    }

    /* Testing   a) If a single user can stake into the contract.
     *           b) totalDeposits and deposits[user] are updated correctly.
     */
    function test_stakeByJohn() public {
        vm.prank(john);
        staking.stake(20000 * 10 ** 18); 
        uint totaldeposts = staking.totalDeposits();
        assertEq(totaldeposts, 20000 * 10 ** 18); 
        uint deposit = staking.deposits(john);
        assertEq(deposit, 20000 * 10 ** 18);
        uint johnBalance = token.balanceOf(john); 
        assertEq(johnBalance, 80000 * 10 ** 18);
    }

    /* Testing   a) If multiple users can stake into the contract.
     *           b) totalDeposits, deposits[john],deposits[kelly] are updated correctly.
     */
    function test_stakeByJohnAndKelly() public {
        test_stakeByJohn();
        vm.prank(kelly);
        staking.stake(30000 * 10 ** 18); // stake 75 test tokens
        uint totaldeposts = staking.totalDeposits();
        assertEq(totaldeposts, 50000 * 10 ** 18); // total deposits in contract should be 100 tokens
        uint deposit = staking.deposits(kelly);
        assertEq(deposit, 30000 * 10 ** 18);
    }

    /* Testing   a) When owner adds rewards to the vault,
     *           b) Vault Balance in Vault and APR in staking should get updated
     */
    function test_ownerAddsRewardTokens_toVault() public {
        test_stakeByJohnAndKelly();
        vm.warp(block.timestamp + yearSeconds / 4); // advancing by 3 months, APR is 5 * 10*16
        vm.prank(owner);  
        uint256 vaultBalanceBefore = 10000 * 10 ** 18;
        uint256 vaultDeposit = 10000 * 10 ** 18;
        vault.depositRewardTokens(vaultDeposit);
        /* Checking if vault balance has been updated*/
        assertEq(vault.getSupply(), vaultBalanceBefore + vaultDeposit);
        /* APR should be doubled, since vault rewards were doubled*/
        assertEq(staking.cumulativeRewardRate(),10*10**16);   
    }

    /* Testing   a) Only John staked in the contract with 100% pool share
     *           b) Calls claim() and should get 100% of the rewards
     */
    function test_onlyJohnInPool_johnClaims() public {
        test_stakeByJohn();
        vm.warp(block.timestamp + yearSeconds / 4); // advancing by 3 months
        vm.prank(john);
        uint rewards = staking.claim(); 
        // should received 2500 rewards for 3 mnths, based on 10k annual rewards in the pool        
        assertEq(rewards, 2500 * 10 ** 18); 
        uint johnBalance = token.balanceOf(john);
        assertEq(johnBalance, 82500 * 10 ** 18);
    }

    /* Testing   a) Multiple users staked in the contract. John has 40% share of the pool
     *           b) John Calls claim() and should get 40% of the rewards
     *           c) Test is to make sure that rewards are distributed proportionally
     */
    function test_johnAndKellyInPool_johnClaims() public {
        test_stakeByJohnAndKelly();
        vm.warp(block.timestamp + yearSeconds / 4);
        vm.prank(john);
        uint rewards = staking.claim(); // john staked 20k tokens for 3 months, 40% of the pool ( 30k staked by kelly)
        assertEq(rewards, 1000 * 10 ** 18); // he should get 40% of 10000*0.25, 40% of 2500 = 1000 tks
        uint johnBalance = token.balanceOf(john);
        assertEq(johnBalance, 81000 * 10 ** 18);
    }

    /* Testing   a) John adds 50k tks more to his stake at t= 3 months
     *           b) Dynamic APR should be adjusted accordingly
     *           c) Rewards Accumulated till t=3 months for John should be updated in rewardsEarned[John]
     *           d) userCumulativeRewardRate[John] should be updated as well
     */
    function test_johnAndKellyInPool_johnStakesMore() public {
        test_stakeByJohnAndKelly();
        vm.warp(block.timestamp + yearSeconds / 4);
        vm.prank(john);
        uint amount = 50000 * 10 ** 18;
        staking.stake(amount); // john staked 50k more tokens, total stake 70k tokens , 70% of the pool
        uint rewardsEarned = staking.rewardsEarned(john); // accumulated rewards will be added to rewardsEarned for John
        assertEq(rewardsEarned, 1000 * 10 ** 18);
        uint johnBalance = staking.deposits(john); 
        assertEq(johnBalance, 70000 * 10 ** 18);
        vm.warp(block.timestamp + yearSeconds / 4);
    }

    /* Testing   a) Same as last scenario, but with autocompounding on.
     *           b) Rewards will be added back to prinicpal. deposits[John] = deposits[John] + rewardsEarned
     *           c) rewardsEarned[John] = 0
     *           d) unlike last scenario, totalDeposits should also be incremented.
     */
    function test_johnAndKellyInPool_johnStakesMore_withAutocompounding()
        public
    {
        test_stakeByJohnAndKelly();
        vm.prank(owner);
        staking.changeCompoundingMode();
        vm.warp(block.timestamp + yearSeconds / 4);
        vm.prank(john);
        uint amount = 50000 * 10 ** 18;
        staking.stake(amount); 
        uint rewardsEarned = staking.rewardsEarned(john);
        assertEq(rewardsEarned, 0); 
        uint johnBalance = staking.deposits(john);
        assertEq(johnBalance, 71000 * 10 ** 18); 
    }

    /* Testing   a) At t= 6 months, John unstakes part of his stake.
     *           b) Making sure if rewards are calculated correctly, since APR has been different
     *              for different time periods.
     *           c) John's ERC20 balance to make sure he received the rewards.
     */
    function test_johnAndKellyInPool_johnUnstakes() public {
        test_johnAndKellyInPool_johnStakesMore(); //CURRENT_POOL : John(70k),Kelly(30k), t= 6 months
        vm.prank(john);
        staking.unstake(40000 * 10 ** 18); // john unstakes 40k tks,
        uint rewardsEarned = staking.rewardsEarned(john); // accumulated rewards will be added to rewardsEarned for John
        assertEq(rewardsEarned, 2750 * 10 ** 18); // Rewards earned : 1k tks + 1.75k tks (from earlier)
        uint johnBalance = staking.deposits(john); // CURRENT POOL : John (30k tks), Kelly (30k tks )
        assertEq(johnBalance, 30000 * 10 ** 18);
    }

    /* This and next test is very important, since they will test the core logic of
     * the algorithim. In this test, Kelly claims his rewards. Kelly's stake has remained same,
     * but his share of the pool has changed.
     * 0 - 3 months ---> Kelly has 60% of the pool ---> Rewards = 1500 tks
     * 3 - 6 seconds ---> Kelly has 30% of the pool ---> Rewards = 750 tokens
     * Total expected Rewards : 2250 tks
     */
    function test_KellyClaims() public {
        test_johnAndKellyInPool_johnStakesMore(); //CURRENT_POOL : John(70k),Kelly(30k), t= 6 months sec
        vm.prank(kelly); // kelly claims
        uint rewards = staking.claim();
        assertEq(rewards, 2250 * 10 ** 18);
        uint kellyBalance = token.balanceOf(kelly);
        assertEq(kellyBalance, 72250 * 10 ** 18);
    }

    /* Kelly claim rewards at t = 6 mnths and John claims at t = 9 mnths. This should affect
     * the supply in the vault. This time cumulativeRewardRate will change not only because of
     * totalDeposits, but also because of the vaultSupply.
     */
    function test_bothJohnAndKellyClaim() public {
        test_johnAndKellyInPool_johnStakesMore(); //CURRENT_POOL : John(70k),Kelly(30k), t= 6 months
        vm.prank(kelly); // kelly claims
        uint kellyRewards = staking.claim();
        assertEq(kellyRewards, 2250 * 10 ** 18); //
        uint vaultSupply = vault.getSupply(); // vault balance = 10000-2250
        assertEq(vaultSupply, 7750 * 10 ** 18);
        vm.warp(block.timestamp + yearSeconds / 4); // advance by 3 months secs, t= 9 months
        vm.prank(john); // john claims
        uint johnRewards = staking.claim(); //
        // Rewards from 6 to 9 months = 70% of 7750*0.3 = 1356.25 , rewards from 0 -6 mnths = 1000 + 1750
        assertEq(johnRewards, 4106250000000000000000); // total --> 4106.25
    }

    /* Testing compound feature */
    function test_compoundMethod() public {
        test_johnAndKellyInPool_johnStakesMore(); //CURRENT_POOL : John(70k),Kelly(30k), t= 6 months
        vm.prank(owner);
        staking.changeCompoundingMode();
        vm.prank(kelly); // kelly claims
        staking.compound();
        assertEq(staking.rewardsEarned(kelly), 0); // rewardsEarned set to 0
        assertEq(staking.deposits(kelly), 32250 * 10 ** 18); // rewards added to Kelly's principal (30k + 2250 tks)
    }

    /* Testing exit pool feature i.e withdraw all stake and all rewards */
    function test_exitPool() public {
        test_johnAndKellyInPool_johnStakesMore(); //CURRENT_POOL : John(70k),Kelly(30k), t= 6 months
        vm.prank(kelly); // kelly claims
        staking.exitPool();
        assertEq(staking.rewardsEarned(kelly), 0); // rewards are set to 0
        assertEq(staking.deposits(kelly), 0); // deposits are set to 0
        assertEq(token.balanceOf(kelly), 102250 * 10 ** 18); // kelly's balance should be 100 k tks + 2250 reward tokens
    }
}
