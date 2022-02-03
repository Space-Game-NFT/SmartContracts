// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IMnA.sol";

contract Traits is Ownable, ITraits {

  using Strings for uint256;

  // struct to store each trait's data for metadata and rendering
  struct Trait {
    string name;
    bool isEmpty;
    string png;
  }

  // mapping from trait type (index) to its name
  string[11] private _traitTypes = [
    "M_Weapon",
    "M_Back",
    "M_Headgear",
    "M_Eyes",
    "M_Emblem",
    "M_Body",
    "A_Headgear",
    "A_Eye",
    "A_Back",
    "A_Mouth",
    "A_Body"
  ];
  // storage of each traits name and base64 PNG data
  mapping(uint8 => mapping(uint8 => Trait)) public traitData;
  // mapping from rankIndex to its score
  string[4] private _ranks = [
    "4",
    "3",
    "2",
    "1"
  ];

  IMnA public mnaNFT;

  constructor() {}

  function setMnA(address _mnaNFT) external onlyOwner {
    mnaNFT = IMnA(_mnaNFT);
  }

  /**
   * administrative to upload the names and images associated with each trait
   * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
   * @param traits the names, empty flags and base64 encoded PNGs for each trait
   */
  function uploadTraits(uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
    require(traitIds.length == traits.length, "Mismatched inputs");
    for (uint i = 0; i < traits.length; i++) {
      traitData[traitType][traitIds[i]] = Trait(
        traits[i].name,
        traits[i].isEmpty,
        traits[i].png
      );
    }
  }

  /**
   * generates an <image> element using base64 encoded PNGs
   * @param trait the trait storing the PNG data
   * @return the <image> element
   */
  function drawTrait(Trait memory trait) internal pure returns (string memory) {
    require(!trait.isEmpty, "Empty trait!!!");
    return string(abi.encodePacked(
      '<image x="0" y="0" width="1024" height="1024" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
      trait.png,
      '"/>'
    ));
  }

  /**
   * generates an entire SVG by composing multiple <image> elements of PNGs
   * @param tokenId the ID of the token to generate an SVG for
   * @return a valid SVG of the Marine / Alien
   */
  function drawSVG(uint256 tokenId) internal view returns (string memory) {
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);
    string memory svgString; 
    if (s.isMarine) {
      svgString = string(abi.encodePacked(
        traitData[0][s.M_Weapon].isEmpty ? '' : drawTrait(traitData[0][s.M_Weapon]),
        traitData[1][s.M_Back].isEmpty ? '' : drawTrait(traitData[1][s.M_Back]),
        traitData[2][s.M_Headgear].isEmpty ? '' : drawTrait(traitData[2][s.M_Headgear]),
        traitData[3][s.M_Eyes].isEmpty ? '' : drawTrait(traitData[3][s.M_Eyes]),
        traitData[4][s.M_Emblem].isEmpty ? '' : drawTrait(traitData[4][s.M_Emblem]),
        traitData[5][s.M_Body].isEmpty ? '' : drawTrait(traitData[5][s.M_Body])
      ));
    } else {
      svgString = string(abi.encodePacked(
        traitData[6][s.A_Headgear].isEmpty ? '' : drawTrait(traitData[6][s.A_Headgear]),
        traitData[7][s.A_Eye].isEmpty ? '' : drawTrait(traitData[7][s.A_Eye]),
        traitData[8][s.A_Back].isEmpty ? '' : drawTrait(traitData[8][s.A_Back]),
        traitData[9][s.A_Mouth].isEmpty ? '' : drawTrait(traitData[9][s.A_Mouth]),
        traitData[10][s.A_Body].isEmpty ? '' : drawTrait(traitData[10][s.A_Body])
      ));
    }
    
    return string(abi.encodePacked(
      '<svg id="mnaNFT" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
      svgString,
      "</svg>"
    ));
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   * @param traitType the trait type to reference as the metadata key
   * @param value the token's trait associated with the key
   * @return a JSON dictionary for the single attribute
   */
  function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '{"trait_type":"',
      traitType,
      '","value":"',
      value,
      '"}'
    ));
  }

  /**
   * generates an array composed of all the individual traits and values
   * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
  function compileAttributes(uint256 tokenId) internal view returns (string memory) {
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);
    string memory traits;
    if (s.isMarine) {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[0], traitData[0][s.M_Weapon].name),',',
        attributeForTypeAndValue(_traitTypes[1], traitData[1][s.M_Back].name),',',
        attributeForTypeAndValue(_traitTypes[2], traitData[2][s.M_Headgear].name),',',
        attributeForTypeAndValue(_traitTypes[3], traitData[3][s.M_Eyes].name),',',
        attributeForTypeAndValue(_traitTypes[4], traitData[4][s.M_Emblem].name),',',
        attributeForTypeAndValue(_traitTypes[5], traitData[5][s.M_Body].name),','
      ));
    } else {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[6], traitData[6][s.A_Headgear].name),',',
        attributeForTypeAndValue(_traitTypes[7], traitData[7][s.A_Eye].name),',',
        attributeForTypeAndValue(_traitTypes[8], traitData[8][s.A_Back].name),',',
        attributeForTypeAndValue(_traitTypes[9], traitData[9][s.A_Mouth].name),',',
        attributeForTypeAndValue(_traitTypes[10], traitData[10][s.A_Body].name),',',
        attributeForTypeAndValue("Rank Score", _ranks[s.rankIndex]),','
      ));
    }
    return string(abi.encodePacked(
      '[',
      traits,
      '{"trait_type":"Generation","value":',
      tokenId <= mnaNFT.getPaidTokens() ? '"Gen 0"' : '"Gen 1"',
      '},{"trait_type":"Type","value":',
      s.isMarine ? '"Marine"' : '"Alien"',
      '}]'
    ));
  }

  /**
   * generates a base64 encoded metadata response without referencing off-chain content
   * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_msgSender() == address(mnaNFT), "hmmmm what doing?");
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);

    string memory metadata = string(abi.encodePacked(
      '{"name": "',
      s.isMarine ? 'Marine #' : 'Alien #',
      tokenId.toString(),
      '", "description": "Space Game is a 100% on-chain collectible based strategy PVE game. Leveraging both L1 & L2. All metadata and pixel sprites are generated and stored completely on-chain. No API and IPFS are used.", "image": "data:image/svg+xml;base64,',
      base64(bytes(drawSVG(tokenId))),
      '", "attributes":',
      compileAttributes(tokenId),
      "}"
    ));

    return string(abi.encodePacked(
      "data:application/json;base64,",
      base64(bytes(metadata))
    ));
  }

  string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function base64(bytes memory data) internal pure returns (string memory) {
    if (data.length == 0) return '';
    
    // load the table into memory
    string memory table = TABLE;

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((data.length + 2) / 3);

    // add some extra buffer at the end required for the writing
    string memory result = new string(encodedLen + 32);

    assembly {
      // set the actual output length
      mstore(result, encodedLen)
      
      // prepare the lookup table
      let tablePtr := add(table, 1)
      
      // input ptr
      let dataPtr := data
      let endPtr := add(dataPtr, mload(data))
      
      // result ptr, jump over length
      let resultPtr := add(result, 32)
      
      // run over the input, 3 bytes at a time
      for {} lt(dataPtr, endPtr) {}
      {
          dataPtr := add(dataPtr, 3)
          
          // read 3 bytes
          let input := mload(dataPtr)
          
          // write 4 characters
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
          resultPtr := add(resultPtr, 1)
      }
      
      // padding with '='
      switch mod(mload(data), 3)
      case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
      case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
    }
    
    return result;
  }
}