import { task } from "hardhat/config";

export default task("set-active-eggmint", "Activate egg minting")
  .addParam("active", "Sets active")
  .addParam("egg", "The name of Egg")
  .setAction(
    async ({ active, egg }, { deployments, getNamedAccounts, ethers }) => {
      const namedAccounts = await getNamedAccounts();

      console.log("active: ", active);
      console.log("namedAccounts: ", namedAccounts.deployer);
      console.log(`Activating ${egg} contract, active:${active}`);
      const eggDeployment = await deployments.get(egg);
      const eggAddress = eggDeployment.address;
      const eggContract = await ethers.getContractAt(egg, eggAddress);
      const tx = await eggContract.setActive(active);
      console.log("activate tx: ", tx);
      const receipt = await tx.wait();
      console.log("activate tx mined: ", receipt.transactionHash);
    }
  );
