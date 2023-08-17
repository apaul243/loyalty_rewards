// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/** 
 * @title Staking
 * @dev Allow users to stake the staking token and get reward tokens in return.
 **/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Vault.sol";
import "hardhat/console.sol";

contract Staking is Ownable,Pausable {

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;    
    Vault public vault;

    /* cumulativeRewardRate: This variable contains the core logic of the contract.
     * It is updated whenever a user: Stakes,Unstakes,Claims,Compound or Exit Pool
     * RewardRate = (totalRewardTokensInVault*multiplier)/(1 year*totalDeposits)
     * cumulativeRewardRate (at t) = SUM(RewardRate) from 0 to t secionds
     * Calculation can vary a bit for fixed APR. 
     * NOTE: Multiplier is 10,000, so apr will vary from 0.01% to 100% , in intervals of 0.01 % 
     */
    uint public cumulativeRewardRate;
    uint public lastUpdateTime; // last update time for cumulativeRewardRate
    uint public totalDeposits; // total staked amount in the contract
    uint private constant RATE_MULTIPLIER = 10**4; 
    uint private constant ETH_MULTIPLIER = 10**18; 
    uint private timePeriod = 31536000; // seconds in an year, for APY calculations
    bool public autocompounding;// autocompounding on/off
    bool public dynamicRate;// APY Calculation : dynamic or fixed
    uint public fixedRate; // For fixed APY, amount of reward tokens in one year per staking token


    mapping(address => uint256) public deposits; 
    /* We calculate user rewards by keeping track of the cumulativeRewardRate() when
     * (1) they entered the pool or (2) when their rewards were last updated.
     * Rewards earned = (cumulativeRewardRate - userCumulativeRewardRate[user])*deposits[user]/multiplier
     */
    mapping(address => uint256) public userCumulativeRewardRate;
    mapping(address => uint256) public rewardsEarned;
    // if rate if fixed, we store and update user's deposit timestamp    
    mapping(address => uint256) public fixedRateUserTimestamps;

    /* Events can be optional since they consume gas.*/
    event stakes(address staker,uint stakeAdded, uint rewards);    
    event unstaked(address staker,uint stakeRemoved, uint rewards); 
    event claimed(address staker, uint rewardsClaimed);   
    event exitedPool(address staker); 
    event autocompoundingMode(bool mode);

    constructor(address _stakingToken, address _rewardToken, address _vault,uint _fixedRate, bool ifCompounding) {
        require(_stakingToken!=address(0),"Staking token cannot be address zero");        
        require(_rewardToken!=address(0),"reward token cannot be address zero");        
        require(_vault!=address(0),"vault cannot be address zero");  
        // If we apply dynamic APR, _fixedRate should be set as 0, otherwise between 1 and 10,000
        if(_fixedRate ==0){
            dynamicRate = true;
        }   
        else {
        require(_fixedRate <10001,"Fixed APR cannot be greater than 100%");    
            fixedRate = _fixedRate;
        }
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        vault = Vault(_vault);        
        autocompounding = ifCompounding;        
    }

    /* @dev a) Allow users to stake in the contract b) If they already have a stake, it calculates the 
     *         rewards earned till now and adds it to rewardsEarned c) If autocompounding is on,
     *         rewards earned are added to the principal.
     */
    function stake(uint amount) external {
        require(amount >0,"Deposit amount has to be > 0");
        uint totalRewardTokens = vault.getSupply();
        if(dynamicRate){
            // if any incoming deposit causes the dynamic apr to drop below 0.01%, it will be rejected          
            require((totalRewardTokens*RATE_MULTIPLIER)/(totalDeposits+amount) >0, "Cannot take more deposits, return rate cannot be less than 0.01%" );     
        }   
        else{
            // Checks if vault rewards are enough to pay out all users for 1 year on the fixed APR 
            // Done to make sure if an incoming stake is very big and vault cannot sustain
            uint expectedPayouts =  ((totalDeposits+amount)*fixedRate)/RATE_MULTIPLIER;
            require( expectedPayouts <totalRewardTokens,"Not enough vault rewards");
        }      
        uint rewards = _updateUserRewards(msg.sender);
        if(autocompounding) {
            deposits[msg.sender] = deposits[msg.sender] + amount + rewards ;
            rewardsEarned[msg.sender] = 0;
            totalDeposits = totalDeposits + amount + rewards;
        }
        else {
            deposits[msg.sender] += amount;
            totalDeposits += amount;            
        }
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit stakes(msg.sender,amount,rewards);

    }

    /* @dev a) Allow users to unstake from the contract b) If autocompounding is on,
     *         it adds the rewards earned to the principal.
     */
    function unstake(uint amount) public {
        require(amount >0,"Unstaking amount has to be > 0"); 
        uint userDeposit = deposits[msg.sender];
        require(userDeposit >0,"User has no deposits in this contracts"); 
        uint rewards = _updateUserRewards(msg.sender);
        if(autocompounding) {
            userDeposit = userDeposit - amount + rewards ;
            rewardsEarned[msg.sender] = 0;
            totalDeposits = totalDeposits - amount + rewards;
        }
        else {
            userDeposit -= amount;
            totalDeposits -= amount;            
        }
        deposits[msg.sender] = userDeposit;
        stakingToken.transfer(msg.sender, amount);
        emit unstaked(msg.sender,amount,rewards);
    }

    /* @dev a) Allow users to claim all accumulated rewards b) Calls the vault contract 
     *      to transfer the tokens to the user ( since rewards tokens are in vault).
     *      c) Also, sets the rewardsEarned[user] = 0    
     */
    function claim() public returns (uint) {
        uint rewards = _updateUserRewards(msg.sender); 
        if (rewards > 0) {
            rewardsEarned[msg.sender] = 0;
            vault.transferStakingTokens(msg.sender, rewards);
        }
        emit claimed(msg.sender,rewards);
        return rewards;        
    }

    /* @dev Allows users to completely exit the pool: claim deposit and rewards */
    function exitPool() external {
        claim();
        unstake(deposits[msg.sender]);
        emit exitedPool(msg.sender); 
    }

    /* @dev If autocompounding is on, allows users to manually calculate rewards and add it to principal */
    function compound() external {
        require(autocompounding, "compounding is turned off");
        uint rewards = _updateUserRewards(msg.sender);
        deposits[msg.sender] = deposits[msg.sender] + rewards ;
        rewardsEarned[msg.sender] = 0;
        totalDeposits = totalDeposits + rewards;
    }

    /* @dev Updates the cumulativeRewardRate based on the last updated timestamp,total deposits and  
     *      total reward tokens. Has custom logic for both fixed and variable rate.  
     */
    function newCumulativeRewardRate() public view returns (uint) {
        uint totalRewardTokens = vault.getSupply();
        if(dynamicRate){
            if (totalDeposits == 0 || totalRewardTokens ==0) {
                return cumulativeRewardRate;
            } 
            // This condition basically caps the apr to a max of 100% i.e 10000 points      
            else if(totalRewardTokens >= totalDeposits) {
                return cumulativeRewardRate + ((block.timestamp - lastUpdateTime)*ETH_MULTIPLIER)/timePeriod;
            }        
            else {
                return cumulativeRewardRate + (
                    (totalRewardTokens*(block.timestamp - lastUpdateTime)*ETH_MULTIPLIER)/(totalDeposits*timePeriod)
                ); 
            } 
        }
        else {
        /* This condition is just needed for test env since initial block is at t = 0*/             
            if(block.timestamp == 0) {
                return 0;
            }  
            uint rewardRate = (fixedRate*ETH_MULTIPLIER)/(RATE_MULTIPLIER*timePeriod);   
            return cumulativeRewardRate + (
                rewardRate*(block.timestamp - lastUpdateTime)
            );            
        }
    }

    /* @dev Calculates the rewards for a given user since the last update time.
     *      Updates rewardsEarned[user] and  userCumulativeRewardRate[user] and
     *      returns the total rewards gained in the time. 
     */
    function _updateUserRewards(address _user) internal returns(uint) {
        uint currentRewards = rewardsEarned[msg.sender];
        if(fixedRate ==0) {
            cumulativeRewardRate = newCumulativeRewardRate();
            lastUpdateTime = block.timestamp;
            currentRewards +=(deposits[_user]*(cumulativeRewardRate - userCumulativeRewardRate[_user]))/ETH_MULTIPLIER;
            userCumulativeRewardRate[_user] = cumulativeRewardRate;  
        }    
        else{
            uint timeElapsed = block.timestamp - fixedRateUserTimestamps[_user];
            currentRewards += (deposits[_user]*fixedRate*timeElapsed)/(RATE_MULTIPLIER*timePeriod);
            fixedRateUserTimestamps[msg.sender] = block.timestamp;        
        }
        rewardsEarned[msg.sender] = currentRewards;
        return currentRewards;                            
    }

    /* @dev Turn compounding on or off  */
    function changeCompoundingMode() external onlyOwner {
        if(autocompounding == false){
            autocompounding = true;
        }
        else {
            autocompounding = false;
        }
        emit autocompoundingMode(autocompounding);
    }

    function changeStakingRateByVault() external {
        require(msg.sender==address(vault),"Only vault can update the staking rate");
        require(fixedRate==0,"Rate only needs to be updated for dynamic staking");
        cumulativeRewardRate = newCumulativeRewardRate();        
    }

    /* @dev  View method to find the current deposit and accumulated  rewards of a user */
    function getUserStakeAndRewards(address _user) public view returns(uint deposit,uint reward){
        uint staked = deposits[_user];
        uint currentUpdatedRewardRate = newCumulativeRewardRate();  
        uint rewards = rewardsEarned[msg.sender] + (staked*(currentUpdatedRewardRate - userCumulativeRewardRate[_user]))/ETH_MULTIPLIER;        
        return (staked,rewards);
    }

}