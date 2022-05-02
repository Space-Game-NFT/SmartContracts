import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import { TraitsData } from "../../scripts/constants/traits";

export default task("upload-traits", "Upload traits data").setAction(
  async ({}, { deployments, getNamedAccounts, ethers }) => {
    const namedAccounts = await getNamedAccounts();

    console.log("namedAccounts: ", namedAccounts.deployer);

    const traitsDeployment = await deployments.get("Traits");
    const traitsAddress = traitsDeployment.address;
    const traitsContract = await ethers.getContractAt("Traits", traitsAddress);

    for (let idx = 0; idx < TraitsData.length; idx++) {
      const traitsDataItem = TraitsData[idx];
      const traitsDataItemData = traitsDataItem.data;

      for (let itemIdx = 0; itemIdx < traitsDataItemData.length; itemIdx++) {
        const item = traitsDataItemData[itemIdx];

        console.log(
          `Uploading traits[${idx}] - ${traitsDataItem.name} - ${item.name}.....`
        );
        const tx = await traitsContract.uploadTraits(
          traitsDataItem.traitType,
          [item.idx],
          [[item.name, item.isEmpty, item.base64Data]],
          {
            gasPrice: "100000000000",
          }
        );

        await tx.wait();
        console.log("Upload traits tx: ", tx);
      }
    }
  }
);
