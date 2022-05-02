pragma solidity ^0.8.0;

interface IRandomSeedGenerator {
    function random() external returns (uint256);
}
