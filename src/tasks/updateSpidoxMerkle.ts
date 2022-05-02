import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import spidoxwhitelist from "../../scripts/constants/spidoxwhitelist";
import AccountTree from "../account-tree";

export default task(
  "update-spidox-merkle",
  "Update spidox merkle root"
).setAction(async ({}, { deployments, getNamedAccounts, ethers }) => {
  const namedAccounts = await getNamedAccounts();

  console.log("namedAccounts: ", namedAccounts.deployer);

  const spidoxDeployment = await deployments.get("Spidox");
  const spidoxAddress = spidoxDeployment.address;
  console.log("spidoxAddress: ", spidoxAddress);

  const spidoxContract = await ethers.getContractAt("Spidox", spidoxAddress);

  const accountTree = new AccountTree(spidoxwhitelist);
  const tx = await spidoxContract.setMerkleRoot(accountTree.getHexRoot(), {
    from: namedAccounts.deployer,
  });

  console.log("update tx: ", tx);
  const receipt = await tx.wait();
  console.log("update tx mined: ", receipt.transactionHash);
});
