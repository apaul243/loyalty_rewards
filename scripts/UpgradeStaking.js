const hre = require('hardhat');

async function main() {

  const newStakingAddress = "";

  const newStaking = await hre.ethers.getContractFactory('StakingUpgradeable');
  const proxy = await upgrades.upgradeProxy(newStaking,[newStakingAddress,tokenAddr,tokenAddr,vaultAddr,true,false] )

  await proxy.deployed();

  console.log('Updated staking contract address is::', proxy.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });