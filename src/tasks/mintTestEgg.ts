import { task } from "hardhat/config";

export default task("mint-testegg", "Mint a token")
  .addParam("numberOfTokens", "The number of tokens")
  .setAction(
    async ({ numberOfTokens }, { deployments, getNamedAccounts, ethers }) => {
      const namedAccounts = await getNamedAccounts();

      console.log("numberOfTokens: ", numberOfTokens);
      console.log("namedAccounts: ", namedAccounts.deployer);

      const testEggDeployment = await deployments.get("TestEgg");
      const testEggAddress = testEggDeployment.address;
      console.log("testEggAddress: ", testEggAddress);

      const testEggContract = await ethers.getContractAt(
        "TestEgg",
        testEggAddress
      );

      const tx = await testEggContract.mint(numberOfTokens);

      console.log("mint tx: ", tx);
      const receipt = await tx.wait();
      console.log("mint tx mined: ", receipt.transactionHash);
    }
  );
