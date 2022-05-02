import { BytesLike, Contract, Signer } from "ethers";
import { artifacts, ethers, network, upgrades } from "hardhat";

export async function deployContract(contractName: string, ...args: any): Promise<Contract> {
    const creation = await ethers.getContractFactory(contractName);
    return await creation.deploy(...args ?? []);
}

export async function deployUpgradeableContract(contractName: string, ...args: any): Promise<Contract> {
    const creation = await ethers.getContractFactory(contractName);
    const instance = await upgrades.deployProxy(creation, [...args] ?? [], { unsafeAllow: ["state-variable-assignment"] });
    return await instance.deployed();
}

export function createNodeHash(nodeA: number, nodeB: number): number {
    return nodeA | (nodeB << 8);
}

export function readNodeHash(nodeHash: number): [number, number] {
    return [nodeHash & 0xFF, nodeHash >> 8];
}

export const blockTimestamp = async (): Promise<number> => {
    return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp
}

export const mineToTimestamp = async (timestamp: number) => {
    const currentTimestamp = (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp
    if (timestamp < currentTimestamp) {
        throw new Error("Cannot mine a timestamp in the past");
    }

    await network.provider.send("evm_increaseTime", [(timestamp - currentTimestamp)])
    await network.provider.send("evm_mine");
}

export const mineForwardSeconds = async (seconds: number) => {
    await mineToTimestamp(await blockTimestamp() + seconds);
}

export const mineForwardDays = async (days: number) => {
    await mineToTimestamp(await blockTimestamp() + (days * 60 * 60 * 1000));
}

interface ITraitDefinition {
    readonly name: string;
    readonly base64: string;
    readonly colorVariants: IColorVariant[];
}

interface IColorVariant {
    readonly name: string;
    readonly base64: string;
}

interface ITraitSet {
    readonly name: string;
    readonly useDisplayName: boolean;
    readonly definitions: ITraitDefinition[];
}

export function createTraitSet(name: string, useDisplayName?: boolean, definitions?: ITraitDefinition[]): ITraitSet {
    return {
        name: name,
        useDisplayName: useDisplayName ?? true,
        definitions: definitions ?? []
    }
}

export function createTraitDefinition(name: string, colorVariants?: IColorVariant[]): ITraitDefinition {
    return {
        name: name,
        base64: "",
        colorVariants: colorVariants ?? []
    }
}

export function createColorVariant(name: string): IColorVariant {
    return {
        name: name,
        base64: ""
    }
}

export function createColorVariants(names: string[]): IColorVariant[] {
    return names.map((name) => {
        return {
            name: name,
            base64: ""
        }
    })
}