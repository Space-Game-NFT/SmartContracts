import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import whitelist from "../../scripts/constants/whitelist";
import AccountTree from "../account-tree";

const sleep = (delay) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

export default task("mint-for-airdrop", "Mint for airdrop").setAction(
  async ({}, { deployments, getNamedAccounts, ethers }) => {
    const namedAccounts = await getNamedAccounts();
    const TOTAL_PAID_TOKENS = 6969;
    console.log("namedAccounts: ", namedAccounts.deployer);
    const mnADeployment = await deployments.get("MnA");
    const mnAAddress = mnADeployment.address;
    console.log("mnAAddress: ", mnAAddress);

    const mnAContract = await ethers.getContractAt("MnA", mnAAddress);

    const totalSupply = await mnAContract.totalSupply();
    console.log("totalSupply: ", totalSupply);
    while (totalSupply < TOTAL_PAID_TOKENS) {
      const estimates = await mnAContract.estimateGas.mintForAirdrop();
      const impactedGasLimit = estimates.mul(120).div(100);
      const tx = await mnAContract.mintForAirdrop({
        gasPrice: "100000000000",
        gasLimit: impactedGasLimit.toString(),
      });
      // // const tx = await mnAContract.mintForAirdrop();
      console.log("mint tx: ", tx);
      const receipt = await tx.wait(1);
      console.log("mint tx mined: ", receipt.transactionHash);
      await sleep(10);
    }
  }
);
