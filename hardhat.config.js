require('dotenv').config();

require('@nomiclabs/hardhat-waffle');
require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-etherscan');
require('solidity-coverage');

// Macros
const optimize = true;
const showGasReporter = true;

module.exports = {
  solidity: {
    version: '0.8.10',
    settings: {
      optimizer: {
        enabled: optimize || showGasReporter || false,
        runs: 999999,
      },
    },
  },
  networks: {
    hardhat: {
      // initialBaseFeePerGas: 0,
    },
    tbsc: {
      url: process.env.BSCTESTNET_ENDPOINT_URL,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
  },
  gasReporter: {
    enabled: showGasReporter,
    currency: 'USD',
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
};
