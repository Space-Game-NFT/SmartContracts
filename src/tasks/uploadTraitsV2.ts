import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import { BackgroundData } from "../../scripts/constants/backgrounds";

export default task("upload-backgrounds", "Upload background data").setAction(
  async ({}, { deployments, getNamedAccounts, ethers }) => {
    const namedAccounts = await getNamedAccounts();

    console.log("namedAccounts: ", namedAccounts.deployer);

    const traitsDeployment = await deployments.get("Traitsv2");
    const traitsAddress = traitsDeployment.address;
    const traitsContract = await ethers.getContractAt(
      "Traitsv2",
      traitsAddress
    );
    for (let idx = 0; idx < 71; idx++) {
      console.log(`Uploading traits[${idx}] .....`);
      const tx = await traitsContract.uploadBackgrounds(
        [idx],
        [BackgroundData[idx].base64Data]
      );
      await tx.wait();
    }

    console.log("Done!");
  }
);
