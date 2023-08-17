const hre = require('hardhat');

async function main() {

  
  const token = await hre.ethers.getContractFactory('TestToken');
  const Token = await token.deploy();
  await Token.deployed();
 
  console.log('Token deployed to:', Token.address);
      
  const vault = await hre.ethers.getContractFactory('Vault');
  const Vault = await vault.deploy(Token.address);  
  await Vault.deployed();

  console.log('Vault deployed to:', Vault.address);


  const staking = await hre.ethers.getContractFactory('StakingUpgradeable');
  const proxy = await upgrades.deployProxy(staking,[Token.address,Token.address,Vault.address,1000,true] )

  await proxy.deployed();

  console.log('Staking deployed to:', proxy.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });