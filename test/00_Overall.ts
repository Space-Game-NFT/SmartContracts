import { BigNumber } from "@ethersproject/bignumber";
import { expect } from "chai";
import { BytesLike, providers, Signer } from "ethers";
import { ethers, upgrades, artifacts } from "hardhat";
import { createNodeHash, deployContract, deployUpgradeableContract, mineForwardDays, mineForwardSeconds, readNodeHash } from "../helpers/TestHelpers";

import {address as MnAv2Address} from "../deployments/matic/MnAv2.json";
import {address as Traitsv2Address} from "../deployments/matic/Traitsv2.json";
import {address as Traitsv1Address} from "../deployments/matic/Traits.json";
import {address as OresAddress} from "../deployments/matic/ORES.json";
import {address as KlayeAddress} from "../deployments/matic/KLAYE.json";
import {address as LevelMathAddress} from "../deployments/matic/LevelMath.json";
import {address as FounderPassAddress} from "../deployments/matic/FounderPass.json";
import {address as RandomSeedGeneratorAddress} from "../deployments/matic/RandomSeedGenerator.json";

describe("SpaceGame Staking", function () {

    let wallet: Signer, wallet1: Signer;

    let staking: any;

    let levelMath: any;
    
    let mna: any;
    let _klaye: any;
    let _ores: any;
    let mnav1: any;
    let traits: any;
    let oldTraits: any;
    let founderPass: any;

    before(async () => {
        [wallet, wallet1] = await ethers.getSigners();

        founderPass = await ethers.getContractFactory("FounderPass");
        founderPass = await founderPass.attach(FounderPassAddress);

        mnav1 = await deployContract("MnA", founderPass.address);

        oldTraits = await ethers.getContractFactory("Traits");
        oldTraits = await oldTraits.attach(Traitsv1Address);

        traits = await deployContract("Traitsv2", oldTraits.address);

        _ores = await deployContract("ORES");

        _klaye = await deployContract("KLAYE");

        mna = await deployContract("MnAv2");
        await traits.setMnAv2(mna.address);
        
        levelMath = await deployContract("LevelMath", 69)
        
        staking = await deployUpgradeableContract("StakingPoolv2");

        let randomSeedGenerator: any = await ethers.getContractFactory("RandomSeedGenerator");
        randomSeedGenerator = randomSeedGenerator.attach(RandomSeedGeneratorAddress);

        await mnav1.setContracts(traits.address, staking.address, randomSeedGenerator.address);

        await staking.setContracts(
            mna.address,
            _klaye.address,
            _ores.address,
            levelMath.address
          );

        await staking.setPaused(false);
        await mnav1.addAdmin(wallet.getAddress());
        await mnav1.setPaused(false);
        await mnav1.mint(wallet.getAddress(), 2312321)
        await mnav1.mint(wallet.getAddress(), 2312321)
        await mnav1.mint(wallet.getAddress(), 2312321)
        await mnav1.mint(wallet.getAddress(), 2312321)
        await mnav1.mint(wallet.getAddress(), 2312321)
        await mnav1.mint(wallet.getAddress(), 2312321)

        let minted = await mnav1.balanceOf(wallet.getAddress())
        console.log(minted)
        let a = await mnav1.ownerOf(1);
        console.log(a);
        
        await mna.setApprovalForAll(staking.address, true);
        await mna.setContracts(mnav1.address, traits.address, _ores.address, _klaye.address, levelMath.address);
        await _ores.addAdmin(wallet.getAddress());
        await _ores.addAdmin(staking.address);
        await _klaye.addAdmin(wallet.getAddress());
        await _klaye.addAdmin(staking.address);
        await _ores.mint(wallet.getAddress(), ethers.utils.parseEther("1000000000000000000"));
        await _klaye.mint(wallet.getAddress(), ethers.utils.parseEther("1000000000000000000"));
        await _ores.approve(mna.address, ethers.utils.parseEther("10000000000000000"));
        await _klaye.approve(mna.address, ethers.utils.parseEther("10000000000000000"));
        await _ores.approve(staking.address, ethers.utils.parseEther("10000000000000000"));
        await _klaye.approve(staking.address, ethers.utils.parseEther("10000000000000000"));
        
        await mna.addAdmin(wallet.getAddress());

        await mna.setPaused(false);
        await mna.updateOriginAccess([1,2,3,4,5])
        await mineForwardDays(5)

        await mnav1.setApprovalForAll(staking.address, true);
        await mnav1.setApprovalForAll(mna.address, true);
        await mnav1.setApprovalForAll("0x000000000000000000000000000000000000dEaD", true);
        await mna.setApprovalForAll("0x000000000000000000000000000000000000dEaD", true);
        
        await mna.claimTokens([1,2,3,4,5])
    });

    describe("SpaceGame", async function() {
        it("Should allow stake", async function () {
            expect(await staking.addManyToMarinePoolAndAlienPool(wallet.getAddress(), [1,2,3,4,5])).ok
        });
        
        it("Should calc correct rewards", async function () {
            let rewards = await staking.calculateRewards(1)
            await mineForwardDays(3);
            rewards = await staking.calculateRewards(1);
            expect(ethers.utils.formatEther(rewards)).to.be.eq("5.0");
        });
        it("Should calc correct rewards", async function() {
            await staking.upgradeLevel([1]);
            await mineForwardDays(5);
            let rewards = await staking.calculateRewards(1);
            expect(ethers.utils.formatEther(rewards)).to.be.eq("6.25");
        });
        it("Should allow unstake", async function() {
            expect(await staking.claimManyFromMarinePoolAndAlienPool([1], true)).ok
        });
        it("Should level up", async function() {
            await mna.upgradeLevel([1]);
        });
        it("Should allow staking again..", async function() {
            expect(await staking.addManyToMarinePoolAndAlienPool(wallet.getAddress(), [1])).ok
        });
        it("Should require level up", async function() {
            await mineForwardDays(5);
            let rewards = await staking.calculateRewards(1);
            console.log(rewards)
            expect(await staking.claimManyFromMarinePoolAndAlienPool([1], true)).ok
            await expect(staking.addManyToMarinePoolAndAlienPool(wallet.getAddress(), [1])).revertedWith("can't stake. upgrade level first")
        });
        it("Should reset on stake", async function() {
            await mna.upgradeLevel([1]);
            expect(await staking.addManyToMarinePoolAndAlienPool(wallet.getAddress(), [1])).ok
        });
        it("Should stake at lvl 70", async function() {
            await mineForwardDays(3)
            expect(await staking.claimManyFromMarinePoolAndAlienPool([1], true)).ok
            for(let i = 2; i < 68; ++i) {
                await mna.upgradeLevel([1]);
                await mna.resetCoolDown([1]);
            }
            expect(await staking.addManyToMarinePoolAndAlienPool(wallet.getAddress(), [1])).ok
        })
    });
});

export const blockTimestamp = async (): Promise<number> => {
    return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp
}