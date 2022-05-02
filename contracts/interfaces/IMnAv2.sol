// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./IMnA.sol";

interface IMnAv2 is IERC721Enumerable {
  function minted() external returns (uint16);

  function updateOriginAccess(uint16[] memory tokenIds) external;

  function getTokenTraits(uint256 tokenId)
    external
    view
    returns (IMnA.MarineAlien memory);

  function getTokenLevel(uint256 tokenId) external view returns (uint256);

  function getTokenWriteBlock(uint256 tokenId) external view returns (uint64);

  function isMarine(uint256 tokenId) external view returns (bool);

  function upgradeLevel(uint256[] calldata tokenIds) external;

  function resetCoolDown(uint256[] calldata tokenIds) external;
}
