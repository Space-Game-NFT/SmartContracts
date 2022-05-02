import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import whitelist from "../../scripts/constants/whitelist";
import AccountTree from "../account-tree";

export default task("mint", "Mint a token")
  .addParam("numberOfTokens", "The number of tokens")
  .setAction(
    async (
      { numberOfTokens, isWhitelisted },
      { deployments, getNamedAccounts, ethers }
    ) => {
      const namedAccounts = await getNamedAccounts();

      console.log("numberOfTokens: ", numberOfTokens);
      console.log("namedAccounts: ", namedAccounts.deployer);

      const founderPassDeployment = await deployments.get("FounderPass");
      const founderPassAddress = founderPassDeployment.address;
      console.log("founderPassAddress: ", founderPassAddress);

      const founderPassContract = await ethers.getContractAt(
        "FounderPass",
        founderPassAddress
      );

      const accountTree = new AccountTree(whitelist);
      let merkleProof = [];
      try {
        merkleProof = accountTree.getProof(namedAccounts.deployer);
      } catch (e) {
        console.log(e);
        merkleProof = [];
      }

      console.log("merkleProof: ", merkleProof);
      const tx = await founderPassContract.mint(numberOfTokens, merkleProof, {
        from: namedAccounts.deployer,
      });

      console.log("mint tx: ", tx);
      const receipt = await tx.wait();
      console.log("mint tx mined: ", receipt.transactionHash);
    }
  );
