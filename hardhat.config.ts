import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "solidity-coverage";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
import "@openzeppelin/hardhat-upgrades";

import "./src/tasks/uploadTraits";
import "./src/tasks/mint";
import "./src/tasks/whitelist";
import "./src/tasks/spidoxwhitelist";
import "./src/tasks/updateMerkle";
import "./src/tasks/mintForAirdrop";
import "./src/tasks/updateSpidoxMerkle";
import "./src/tasks/updateMaxMint";
import "./src/tasks/updateGameSeed";
import "./src/tasks/setActiveEggMint";
import "./src/tasks/mintTestEgg";
import "./src/tasks/uploadTraitsV2";
import "./src/tasks/setActive";
import "./src/tasks/setStakingPoolv2";
import * as dotenv from "dotenv";

dotenv.config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.2",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  namedAccounts: {
    deployer: { default: 0 },
    alice: { default: 1 },
    bob: { default: 2 },
    rando: { default: 3 },
  },
  networks: {
    rinkeby: {
      url: process.env.RPC_ENDPOINT,
      accounts: [process.env.PRIVATE_KEY !== undefined ? process.env.PRIVATE_KEY : ""],
    },
    matic: {
      url: process.env.MATIC_RPC_ENDPOINT,
      accounts: [process.env.MATIC_PRIVATE_KEY !== undefined ? process.env.MATIC_PRIVATE_KEY : ""],
    },
    hardhat: {
      mining: {
        auto: true
      },
      accounts: [
        {
          privateKey: process.env.MATIC_PRIVATE_KEY !== undefined ? process.env.MATIC_PRIVATE_KEY : "",
          balance: "10000000000000000000000"
        },
      ],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
