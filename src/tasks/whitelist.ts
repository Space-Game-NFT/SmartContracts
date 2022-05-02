import { task } from "hardhat/config";
import whitelist from "../../scripts/constants/whitelist";
import AccountTree from "../account-tree";

export default task("whitelist", "Check if account is in whitelist")
  .addParam("account", "The account being checked")
  .setAction(async ({ account }, { deployments, ethers }) => {
    console.log("account: ", account);
    const founderPassDeployment = await deployments.get("FounderPass");
    const founderPassAddress = founderPassDeployment.address;
    console.log("founderPassAddress: ", founderPassAddress);

    const founderPassContract = await ethers.getContractAt(
      "FounderPass",
      founderPassAddress
    );

    const accountTree = new AccountTree(whitelist);
    try {
      const merkleProof = accountTree.getProof(account);
      const whitelisted = await founderPassContract.isWhiteList(
        account,
        merkleProof
      );
      console.log("isWhitelisted: ", whitelisted);
    } catch (error) {
      console.log(error);
    }
  });
