import { task } from "hardhat/config";
import spidoxwhitelist from "../../scripts/constants/spidoxwhitelist";
import AccountTree from "../account-tree";

export default task("spidox-whitelist", "Check if account is in whitelist")
  .addParam("account", "The account being checked")
  .setAction(async ({ account }, { deployments, ethers }) => {
    console.log("account: ", account);
    const spidoxDeployment = await deployments.get("Spidox");
    const spidoxAddress = spidoxDeployment.address;
    console.log("spidoxAddress: ", spidoxAddress);

    const spidoxContract = await ethers.getContractAt("Spidox", spidoxAddress);

    const accountTree = new AccountTree(spidoxwhitelist);
    try {
      const merkleProof = accountTree.getProof(account);
      const whitelisted = await spidoxContract.isWhiteList(
        account,
        merkleProof
      );
      console.log("isWhitelisted: ", whitelisted);
    } catch (error) {
      console.log(error);
    }
  });
