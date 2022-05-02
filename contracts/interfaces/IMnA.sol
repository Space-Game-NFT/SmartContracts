// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IMnA is IERC721Enumerable {
    // game data storage
    struct MarineAlien {
        bool isMarine;
        uint8 M_Weapon;
        uint8 M_Back;
        uint8 M_Headgear;
        uint8 M_Eyes;
        uint8 M_Emblem;
        uint8 M_Body;
        uint8 A_Headgear;
        uint8 A_Eye;
        uint8 A_Back;
        uint8 A_Mouth;
        uint8 A_Body;
        uint8 rankIndex;
    }

    function minted() external returns (uint16);

    function updateOriginAccess(uint16[] memory tokenIds) external;

    function mint(address recipient, uint256 seed) external;

    function burn(uint256 tokenId) external;

    function getMaxTokens() external view returns (uint256);

    function getPaidTokens() external view returns (uint256);

    function getTokenTraits(uint256 tokenId)
        external
        view
        returns (MarineAlien memory);

    function getTokenWriteBlock(uint256 tokenId) external view returns (uint64);

    function isMarine(uint256 tokenId) external view returns (bool);
}
