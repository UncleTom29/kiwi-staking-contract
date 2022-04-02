const hre = require('hardhat');

const { verify } = require('./utils');

async function main() {
  const KiwiETH = await hre.ethers.getContractFactory('KiwiETH');
  const kiwiETH = await KiwiETH.deploy('KiwiETH', 'KETH');
  await kiwiETH.deployed();
  console.log('KiwiETH deployed to:', kiwiETH.address);
  await verify('KiwiETH', kiwiETH.address, ['KiwiETH', 'KETH']);

  const Kiwi = await hre.ethers.getContractFactory('Kiwi');
  const kiwi = await Kiwi.deploy(kiwiETH.address);
  await kiwi.deployed();
  console.log('Kiwi deployed to:', kiwi.address);
  await verify('Kiwi', kiwi.address, [kiwiETH.address]);

  await kiwiETH.setMinter(kiwi.address, true);
  console.log('Kiwi set to KiwiETH minter');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
