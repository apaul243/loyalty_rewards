const hre = require('hardhat');
const {account} = process.env;

async function main() {
  
  const whitelistContract = await hre.ethers.getContractFactory('RewardsWhitelist');
  const WhitelistContract = await whitelistContract.deploy(account);  
  await WhitelistContract.deployed();

  console.log('WhitelistContract deployed to:', WhitelistContract.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });