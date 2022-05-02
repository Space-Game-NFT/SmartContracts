import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import whitelist from "../../scripts/constants/whitelist";
import AccountTree from "../account-tree";

export default task("update-merkle", "Update merkle root").setAction(
  async ({}, { deployments, getNamedAccounts, ethers }) => {
    const namedAccounts = await getNamedAccounts();

    console.log("namedAccounts: ", namedAccounts.deployer);

    const founderPassDeployment = await deployments.get("FounderPass");
    const founderPassAddress = founderPassDeployment.address;
    console.log("founderPassAddress: ", founderPassAddress);

    const founderPassContract = await ethers.getContractAt(
      "FounderPass",
      founderPassAddress
    );

    const accountTree = new AccountTree(whitelist);
    const tx = await founderPassContract.setMerkleRoot(
      accountTree.getHexRoot(),
      {
        from: namedAccounts.deployer,
      }
    );

    console.log("update tx: ", tx);
    const receipt = await tx.wait();
    console.log("update tx mined: ", receipt.transactionHash);
  }
);
