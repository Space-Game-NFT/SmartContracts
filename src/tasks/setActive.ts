import { task } from "hardhat/config";

export default task("set-active-v2", "Activate MnAv2 contracts").setAction(
  async ({}, { deployments, getNamedAccounts, ethers }) => {
    const namedAccounts = await getNamedAccounts();

    console.log("namedAccounts: ", namedAccounts.deployer);

    const mnAv2Deployment = await deployments.get("MnAv2");
    const mnAv2Address = mnAv2Deployment.address;
    const mnAv2Contract = await ethers.getContractAt("MnAv2", mnAv2Address);

    const mnAv1Deployments = await deployments.get("MnA");
    const traitsv2Deployments = await deployments.get("Traitsv2");
    const oresDeployments = await deployments.get("ORES");
    const klayeDeployments = await deployments.get("KLAYE");
    const levelMathDeployments = await deployments.get("LevelMath");
    let tx = await mnAv2Contract.setContracts(
      mnAv1Deployments.address,
      traitsv2Deployments.address,
      oresDeployments.address,
      klayeDeployments.address,
      levelMathDeployments.address
    );
    await tx.wait();
    console.log("setContracts tx mined: ", tx);
    // tx = await mnAv2Contract.setPaused(false);
    // console.log("setPaused tx mined: ", tx);
    // await tx.wait();
    console.log("Done!");
  }
);
