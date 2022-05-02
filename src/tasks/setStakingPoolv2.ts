import { task } from "hardhat/config";

export default task(
  "set-staking-v2",
  "Activate StakingPoolv2 contracts"
).setAction(async ({}, { deployments, getNamedAccounts, ethers }) => {
  const namedAccounts = await getNamedAccounts();

  console.log("namedAccounts: ", namedAccounts.deployer);

  const stakingPoolv2Deployment = await deployments.get("StakingPoolv2");
  const stakingPoolv2Address = stakingPoolv2Deployment.address;
  const stakingPoolv2Contract = await ethers.getContractAt(
    "StakingPoolv2",
    stakingPoolv2Address
  );

  const mnAv1Deployments = await deployments.get("MnAv2");
  const oresDeployments = await deployments.get("ORES");
  const klayeDeployments = await deployments.get("KLAYE");
  const levelMathDeployments = await deployments.get("LevelMath");
  let tx = await stakingPoolv2Contract.setContracts(
    mnAv1Deployments.address,
    klayeDeployments.address,
    oresDeployments.address,
    levelMathDeployments.address
  );
  await tx.wait();
  console.log("setContracts tx mined: ", tx);
  tx = await stakingPoolv2Contract.setPaused(false);
  console.log("setPaused tx mined: ", tx);
  await tx.wait();
  console.log("Done!");
});
