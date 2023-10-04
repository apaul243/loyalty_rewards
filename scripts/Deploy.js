const hre = require('hardhat');

async function main() {
  
  let coordinator = "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed" 
  let hash = "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f"
  let subid = 6103

  const random = await hre.ethers.getContractFactory('RewardsLottery');
  const Random = await random.deploy(subid,coordinator,hash);  
  await Random.deployed();

  console.log('Random deployed to:', Random.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });