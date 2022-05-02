// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IMnA.sol";
import "./interfaces/IMnAv2.sol";
import "./Traits.sol";

contract Traitsv2 is Ownable, ITraits {
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
  // mapping from level to background image
  mapping(uint256 => string) public backgrounds;
  // mapping from rankIndex to its score
  string[4] private _ranks = ["4", "3", "2", "1"];

  IMnAv2 public mnaNFT;
  Traits public v1Traits;

  constructor(address _traitV1) {
    v1Traits = Traits(_traitV1);
  }

  function setMnAv2(address _mnaNFT) external onlyOwner {
    mnaNFT = IMnAv2(_mnaNFT);
  }

  /**
   * administrative to upload the levels and images associated to trait
   * @param _levels the trait levels to upload
   * @param _backgrounds the base64 encoded PNGs for each level
   */
  function uploadBackgrounds(
    uint8[] calldata _levels,
    string[] calldata _backgrounds
  ) external onlyOwner {
    require(_levels.length == _backgrounds.length, "Mismatched inputs");
    for (uint256 i = 0; i < _levels.length; i++) {
      backgrounds[_levels[i]] = _backgrounds[i];
    }
  }

  /**
   * generates an <image> element using base64 encoded PNGs
   * @param typeIndex the index of trait type
   * @param nodeIndex the node index among the same traits
   * @return the <image> element
   */
  function drawTrait(uint8 typeIndex, uint8 nodeIndex)
    internal
    view
    returns (string memory)
  {
    (, bool isEmpty, string memory png) = v1Traits.traitData(
      typeIndex,
      nodeIndex
    );
    if (isEmpty) return "";
    return
      string(
        abi.encodePacked(
          '<image x="32" y="32" width="1024" height="1024" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
          png,
          '"/>'
        )
      );
  }

  /**
   * generates an <image> element using base64 encoded PNGs
   * @param png the PNG data of background image
   * @return the <image> element
   */
  function drawBackground(string memory png)
    internal
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          '<image x="0" y="0" width="1088" height="1088" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
          png,
          '"/>'
        )
      );
  }

  /**
   * generates an entire SVG by composing multiple <image> elements of PNGs
   * @param tokenId the ID of the token to generate an SVG for
   * @return a valid SVG of the Marine / Alien
   */
  function drawSVG(uint256 tokenId) internal view returns (string memory) {
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);
    uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
    string memory svgString;
    if (s.isMarine) {
      svgString = string(
        abi.encodePacked(
          drawBackground(backgrounds[tokenLevel]),
          drawTrait(5, s.M_Body),
          drawTrait(4, s.M_Emblem),
          drawTrait(3, s.M_Eyes),
          drawTrait(2, s.M_Headgear),
          drawTrait(1, s.M_Back),
          drawTrait(0, s.M_Weapon)
        )
      );
    } else {
      svgString = string(
        abi.encodePacked(
          drawBackground(backgrounds[tokenLevel]),
          drawTrait(10, s.A_Body),
          drawTrait(9, s.A_Mouth),
          drawTrait(8, s.A_Back),
          drawTrait(7, s.A_Eye),
          drawTrait(6, s.A_Headgear)
        )
      );
    }

    return
      string(
        abi.encodePacked(
          '<svg id="mnaNFTv2" width="100%" height="100%" version="1.1" viewBox="0 0 1088 1088" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
          svgString,
          "</svg>"
        )
      );
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   * @param typeIndex the trait type index
   * @param nodeIndex the node index among the same traits
   * @return a JSON dictionary for the single attribute
   */
  function attributeForTypeAndValue(uint8 typeIndex, uint8 nodeIndex)
    internal
    view
    returns (string memory)
  {
    string memory traitType = _traitTypes[typeIndex];
    (string memory name, , ) = v1Traits.traitData(typeIndex, nodeIndex);
    return
      string(
        abi.encodePacked(
          '{"trait_type":"',
          traitType,
          '","value":"',
          name,
          '"}'
        )
      );
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   * @param traitType the trait type string
   * @param name the trait type name
   * @return a JSON dictionary for the single attribute
   */
  function attributeForTypeAndValue2(
    string memory traitType,
    string memory name
  ) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '{"trait_type":"',
          traitType,
          '","value":"',
          name,
          '"}'
        )
      );
  }

  /**
   * generates an array composed of all the individual traits and values
   * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
  function compileAttributes(uint256 tokenId)
    internal
    view
    returns (string memory)
  {
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);
    uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
    string memory traits;
    if (s.isMarine) {
      traits = string(
        abi.encodePacked(
          attributeForTypeAndValue(0, s.M_Weapon),
          ",",
          attributeForTypeAndValue(1, s.M_Back),
          ",",
          attributeForTypeAndValue(2, s.M_Headgear),
          ",",
          attributeForTypeAndValue(3, s.M_Eyes),
          ",",
          attributeForTypeAndValue(4, s.M_Emblem),
          ",",
          attributeForTypeAndValue(5, s.M_Body),
          ",",
          attributeForTypeAndValue2("Level", tokenLevel.toString()),
          ","
        )
      );
    } else {
      traits = string(
        abi.encodePacked(
          attributeForTypeAndValue(6, s.A_Headgear),
          ",",
          attributeForTypeAndValue(7, s.A_Eye),
          ",",
          attributeForTypeAndValue(8, s.A_Back),
          ",",
          attributeForTypeAndValue(9, s.A_Mouth),
          ",",
          attributeForTypeAndValue(10, s.A_Body),
          ",",
          attributeForTypeAndValue2("Level", tokenLevel.toString()),
          ",",
          attributeForTypeAndValue2("Rank Score", _ranks[s.rankIndex]),
          ","
        )
      );
    }
    return
      string(
        abi.encodePacked(
          "[",
          traits,
          '{"trait_type":"Generation","value":',
          tokenId <= 6969 ? '"Gen 0"' : '"Gen 1"',
          '},{"trait_type":"Type","value":',
          s.isMarine ? '"Marine"' : '"Alien"',
          "}]"
        )
      );
  }

  /**
   * generates a base64 encoded metadata response without referencing off-chain content
   * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(_msgSender() == address(mnaNFT), "hmmmm what doing?");
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);

    string memory metadata = string(
      abi.encodePacked(
        '{"name": "',
        s.isMarine ? "Marine #" : "Alien #",
        tokenId.toString(),
        '", "description": "Space Game is a 100% on-chain collectible based strategy PVE game. Leveraging both L1 & L2. All metadata and pixel sprites are generated and stored completely on-chain. No API and IPFS are used.", "image": "data:image/svg+xml;base64,',
        base64(bytes(drawSVG(tokenId))),
        '", "attributes":',
        compileAttributes(tokenId),
        "}"
      )
    );

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          base64(bytes(metadata))
        )
      );
  }

  string internal constant TABLE =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  function base64(bytes memory data) internal pure returns (string memory) {
    if (data.length == 0) return "";

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
      for {

      } lt(dataPtr, endPtr) {

      } {
        dataPtr := add(dataPtr, 3)

        // read 3 bytes
        let input := mload(dataPtr)

        // write 4 characters
        mstore(
          resultPtr,
          shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
        )
        resultPtr := add(resultPtr, 1)
        mstore(
          resultPtr,
          shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
        )
        resultPtr := add(resultPtr, 1)
        mstore(
          resultPtr,
          shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
        )
        resultPtr := add(resultPtr, 1)
        mstore(resultPtr, shl(248, mload(add(tablePtr, and(input, 0x3F)))))
        resultPtr := add(resultPtr, 1)
      }

      // padding with '='
      switch mod(mload(data), 3)
      case 1 {
        mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
      }
      case 2 {
        mstore(sub(resultPtr, 1), shl(248, 0x3d))
      }
    }

    return result;
  }
}
