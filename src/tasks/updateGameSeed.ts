import { task } from "hardhat/config";

const sleep = (delay: any) =>
  new Promise((resolve) => setTimeout(resolve, delay * 1000));

export default task("update-game-seed", "Update game seed")
  .addParam("delay", "Delay")
  .setAction(async ({ delay }, { deployments, getNamedAccounts, ethers }) => {
    while (1) {
      try {
        const namedAccounts = await getNamedAccounts();

        console.log("namedAccounts: ", namedAccounts.deployer);

        const gameCrDeployment = await deployments.get("MnAGameCR");
        const gameCrAddress = gameCrDeployment.address;

        const randomeSeedDeployment = await deployments.get(
          "RandomSeedGenerator"
        );
        const randomeSeedAddress = randomeSeedDeployment.address;

        console.log("GameCRAddress: ", gameCrAddress);

        const gameContract = await ethers.getContractAt(
          "MnAGameCR",
          gameCrAddress
        );
        const randomSeedContract = await ethers.getContractAt(
          "RandomSeedGenerator",
          randomeSeedAddress
        );

        const randomNumber = await randomSeedContract.random();
        console.log({ randomNumber });

        const estimates = await gameContract.estimateGas.addCommitRandom(
          randomNumber
        );
        const impactedGasLimit = estimates.mul(120).div(100);
        const tx = await gameContract.addCommitRandom(randomNumber, {
          gasPrice: "50000000000",
          gasLimit: impactedGasLimit.toString(),
        });

        console.log("addCommitRandom tx: ", tx);
        const receipt = await tx.wait();
        console.log("addCommitRandom tx mined: ", receipt.transactionHash);

        await sleep(delay);
      } catch (e) {
        console.log(e);
        await sleep(delay);
      }
    }
  });
