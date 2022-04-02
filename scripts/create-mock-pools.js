const hre = require('hardhat');

const { verify } = require('./utils');
const address = require('../address.json');
const { Kiwi: kiwiAddress } = address[hre.network.name];

async function main() {
  for (let i = 0; i < 3; i += 1) {
    const MockERC20 = await hre.ethers.getContractFactory('MockERC20');
    const mockERC20 = await MockERC20.deploy(`Mock Token ${i}`, `MT${i}`);
    await mockERC20.deployed();
    console.log(`Mock token ${i} deployed to: `, mockERC20.address);

    await verify(`Mock Token ${i}`, mockERC20.address, [`Mock Token ${i}`, `MT${i}`]);

    await mockERC20.getTokens();
    console.log(`Mock tokens ${i} minted`);

    const kiwi = await hre.ethers.getContractAt('Kiwi', kiwiAddress);
    await kiwi.createPool(
      mockERC20.address,
      13000 * (i + 1),
      100 * (i + 1),
      i + 1,
      '4000000000000000000000',
      3600 * (i + 1),
    );
    console.log(`Pool created for mock token ${i}`);

    const signers = await hre.ethers.getSigners();

    for (let j = 0; j < 3; j += 1) {
      await mockERC20.connect(signers[j]).approve(kiwiAddress, hre.ethers.constants.MaxUint256);
      console.log(`${signers[j].address} approved Kiwi for Mock Token ${i}`);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
