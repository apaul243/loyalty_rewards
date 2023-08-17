// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import {Staking} from "../contracts/Staking.sol";
import "../contracts/Vault.sol";
import "../contracts/TestToken.sol";

// Since all the test have been done in dynamicStakingTest, this will just test the 
// functionalities of fixed staking that are different from dynamic staking
contract fixedStakingTest is Test {
    TestToken public token;
    Vault public vault;
    Staking public staking;
    address owner = makeAddr("owner");
    address john = makeAddr("john");
    address kelly = makeAddr("kelly");
    uint yearSeconds = 31536000;

    function setUp() public {
        vm.startPrank(owner);
        /* Deploy Token, Vault and staking contracts */
        token = new TestToken();
        vault = new Vault(address(token));
        staking = new Staking(
            address(token),
            address(token),
            address(vault),
            2000, // assuming 20% apy
            true
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

    /* Testing   a) John stakes 40k and kelly tries to stake 20k
     *           b) Since, total expected rewards would be 12k, that is greater than the
     *              balance of 10k, deposit would be rejeceted
     */
    function test_rejectDeposit_ifRewardsExceedBalance() public {
        vm.prank(john);
        staking.stake(40000 * 10 ** 18); // john stake 40k tokens 
        vm.prank(kelly);
        vm.expectRevert(bytes("Not enough vault rewards"));
        staking.stake(20000 * 10 ** 18); 
    }

    /* Testing   a) John stakes 10k into the contract for one year
     *           b) and should receive 2k rewards@20% apr
     */
    function test_johnClaims_atFixedRate() public {
        vm.prank(john);
        staking.stake(10000 * 10 ** 18); // stake 10k tokens
        uint totaldeposts = staking.totalDeposits();
        assertEq(totaldeposts, 10000 * 10 ** 18); // total deposits should be 10k
        vm.warp(block.timestamp + yearSeconds); // advancing by one yeaar
        vm.prank(john);
        uint rewards = staking.claim(); 
        assertEq(rewards, 2000 * 10 ** 18); // 2k rewards received
    }

    /* Testing   a) Multiple users stake at t =0 and claim at different times.
     *           b) Should receive rewards @ same rate, irrespective of tokens in vault or totalDeposits
     */
    function test_johnAndKellyClaim_atFixedRate() public {
        vm.prank(john);
        staking.stake(10000 * 10 ** 18); // john stake 10k tokens 
        vm.prank(kelly);
        staking.stake(10000 * 10 ** 18); // john stake 10k tokens 
        vm.warp(block.timestamp + yearSeconds/2); // advancing by 6 months
        vm.prank(john);
        uint rewards = staking.claim(); // john claim at 6 months
        assertEq(rewards, 1000 * 10 ** 18); // 1k rewards received    
        vm.warp(block.timestamp + yearSeconds/2); // advancing by 6 months
        vm.prank(kelly);
        uint rewards2 = staking.claim(); //// kelly claims at 1 year
        assertEq(rewards2, 2000 * 10 ** 18); // 2k rewards received                              
    }

    /* Testing   a) John stakes different amount at different times.
     *           b) Calculations should be done correctly
     */
    function test_johnAddsToHisStakeAndClaims_atFixedRate() public {
        test_johnClaims_atFixedRate();       
        vm.prank(john);
        staking.stake(20000 * 10 ** 18); // stake 20k more tokens, total depost = 25k
        vm.warp(block.timestamp + yearSeconds/4); // advancing by 3 months
        vm.prank(john);
        uint rewards = staking.claim(); // rewards => 30*0.25*0.2 = 1500
        assertEq(rewards, 1500 * 10 ** 18); 
    }

    /* Testing   a) John deposits and calls compound after 1 year
     *           b) Calculations should be done correctly
     */
    function test_johnCompounds_atFixedRate() public {
        vm.prank(john);
        staking.stake(10000 * 10 ** 18); // stake 10k tokens
        vm.warp(block.timestamp + yearSeconds); // advancing by one yeaar
        vm.prank(john);
        staking.compound(); 
        assertEq(staking.deposits(john), 12000 * 10 ** 18); // new balance = 10k(balance) + 2k(compounded rewards)
    }

}
