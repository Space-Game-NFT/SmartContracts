// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMnA.sol";
import "./interfaces/IORES.sol";
import "./interfaces/IMnAv2.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/ILevelMath.sol";

import "./libraries/ERC721A.sol";

contract MnAv2 is IMnAv2, IERC721Receiver, ERC721Enumerable, Ownable, Pausable {
  struct LastWrite {
    uint64 time;
    uint64 blockNum;
  }

  struct UpgradeEpoch {
    bool skipped;
    uint256 lastUpdate;
  }

  event MarineBurned(uint256 indexed tokenId);
  event AlienBurned(uint256 indexed tokenId);

  // number of tokens have been minted so far
  uint16 public override minted;

  uint256 public MAX_LEVEL = 69;

  // mapping from tokenId to level number
  mapping(uint256 => uint256) private tokenLevels;
  // mapping from tokenId to UpgradeEpoch
  mapping(uint256 => UpgradeEpoch) public upgradeEpoches;
  // mapping from tokenId to a struct containing the token's traits
  mapping(uint256 => IMnA.MarineAlien) private tokenTraits;
  // mapping from hashed(tokenTrait) to the tokenId it's associated with
  // used to ensure there are no duplicates
  mapping(uint256 => uint256) public existingCombinations;
  // Tracks the last block and timestamp that a caller has written to state.
  // Disallow some access to functions if they occur while a change is being written.

  mapping(address => LastWrite) private lastWriteAddress;
  mapping(uint256 => LastWrite) private lastWriteToken;

  address public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // reference to Traits
  ITraits public traits;

  // MnA v1 address
  IMnA public mnaV1;

  // ORES token address
  IORES public ores;

  // KLAYE token address
  IERC20 public klaye;

  // LevelMath contract address
  ILevelMath public levelMath;

  // address => allowedToCallFunctions
  mapping(address => bool) private admins;

  constructor() ERC721("Marines & Aliens Game v2", "MnAv2") {
    _pause();
  }

  modifier requireContractsSet() {
    require(
      address(traits) != address(0) &&
        address(mnaV1) != address(0) &&
        address(ores) != address(0) &&
        address(levelMath) != address(0) &&
        address(klaye) != address(0),
      "Contracts not set"
    );
    _;
  }

  modifier blockIfChangingAddress() {
    // frens can always call whenever they want :)
    require(
      admins[_msgSender()] ||
        lastWriteAddress[tx.origin].blockNum < block.number,
      "hmmmm what doing?"
    );
    _;
  }

  modifier blockIfChangingToken(uint256 tokenId) {
    // frens can always call whenever they want :)
    require(
      admins[_msgSender()] || lastWriteToken[tokenId].blockNum < block.number,
      "hmmmm what doing?"
    );
    _;
  }

  function setContracts(
    address _mnaV1,
    address _traits,
    address _ores,
    address _klaye,
    address _levelMath
  ) external onlyOwner {
    mnaV1 = IMnA(_mnaV1);
    traits = ITraits(_traits);
    ores = IORES(_ores);
    klaye = IERC20(_klaye);
    levelMath = ILevelMath(_levelMath);
  }

  /**
   * Mint a token - any payment / game logic should be handled in the game contract.
   * This will just generate random traits and mint a token to a designated address.
   */
  function mintInternal(address recipient, uint256 tokenId)
    internal
    whenNotPaused
  {
    minted++;
    upgradeEpoches[tokenId] = UpgradeEpoch(false, block.timestamp);
    _safeMint(recipient, tokenId);
  }

  function getTokenWriteBlock(uint256 tokenId)
    external
    view
    override
    returns (uint64)
  {
    require(admins[_msgSender()], "Only admins can call this");
    return lastWriteToken[tokenId].blockNum;
  }

  /**
   * Claims the MnAv2 tokens by burning some MnAv2 tokens.
   * Used to avoid estimateGas failure
   */
  function claimTokens(uint256[] calldata tokenIds) external whenNotPaused {
    for (uint256 index = 0; index < tokenIds.length; index++) {
      uint256 tokenId = tokenIds[index];
      require(mnaV1.ownerOf(tokenId) == msg.sender, "not owner");
      IMnA.MarineAlien memory s = mnaV1.getTokenTraits(tokenId);
      tokenTraits[tokenId] = s;
      mnaV1.safeTransferFrom(msg.sender, DEAD_ADDRESS, tokenId);
      mintInternal(msg.sender, tokenId);
    }
  }

  /**
   * Upgrades current level upto next one. $ORES token is required to do.
   * @param tokenIds - The token ids what you're going to upgrade
   */
  function upgradeLevel(uint256[] calldata tokenIds)
    external
    override
    whenNotPaused
  {
    require(tokenIds.length > 0, "invalid param");
    uint256 totalOresToken = 0;
    for (uint256 index = 0; index < tokenIds.length; index++) {
      uint256 tokenId = tokenIds[index];
      uint256 tokenLevel = tokenLevels[tokenId];
      require(ownerOf(tokenId) == msg.sender, "not owner");
      require(tokenLevel <= MAX_LEVEL, "Already max level");
      UpgradeEpoch memory upgradeEpoch = upgradeEpoches[tokenId];
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );
      if (!upgradeEpoch.skipped) {
        require(
          upgradeEpoch.lastUpdate + levelEpoch.coolDownTime < block.timestamp,
          "needs to wait for the cooldown duration"
        );
      }

      totalOresToken += levelEpoch.oresToken;
      tokenLevels[tokenId] = tokenLevel + 1;
      upgradeEpoches[tokenId] = UpgradeEpoch(false, block.timestamp);
    }
    require(ores.transferFrom(msg.sender, DEAD_ADDRESS, totalOresToken));
  }

  /**
   * Resets cooldown time to upgrade immediately.
   * @param tokenIds - The token ids what you're going to reset
   */
  function resetCoolDown(uint256[] calldata tokenIds)
    external
    override
    whenNotPaused
  {
    require(tokenIds.length > 0, "invalid param");
    uint256 totalKlayeToken = 0;
    for (uint256 index = 0; index < tokenIds.length; index++) {
      uint256 tokenId = tokenIds[index];
      uint256 tokenLevel = tokenLevels[tokenId];
      require(tokenLevel <= MAX_LEVEL, "already max level");

      UpgradeEpoch memory upgradeEpoch = upgradeEpoches[tokenId];
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );
      require(!upgradeEpoch.skipped, "already reset");
      totalKlayeToken += levelEpoch.klayeToSkip;
      upgradeEpoches[tokenId] = UpgradeEpoch(true, block.timestamp);
    }
    require(klaye.transferFrom(msg.sender, DEAD_ADDRESS, totalKlayeToken));
  }

  /**
   * Burn a token - any game logic should be handled before this function.
   */
  function burn(uint256 tokenId) external whenNotPaused {
    require(admins[_msgSender()], "Only admins can call this");
    require(ownerOf(tokenId) == tx.origin, "Oops you don't own that");
    if (tokenTraits[tokenId].isMarine) {
      emit MarineBurned(tokenId);
    } else {
      emit AlienBurned(tokenId);
    }
    _burn(tokenId);
  }

  function updateOriginAccess(uint16[] memory tokenIds) external override {
    require(admins[_msgSender()], "Only admins can call this");
    uint64 blockNum = uint64(block.number);
    uint64 time = uint64(block.timestamp);
    lastWriteAddress[tx.origin] = LastWrite(time, blockNum);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      lastWriteToken[tokenIds[i]] = LastWrite(time, blockNum);
    }
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override(ERC721, IERC721) blockIfChangingToken(tokenId) {
    // allow admin contracts to be send without approval
    if (!admins[_msgSender()]) {
      require(
        _isApprovedOrOwner(_msgSender(), tokenId),
        "ERC721: transfer caller is not owner nor approved"
      );
    }
    _transfer(from, to, tokenId);
  }

  /** READ */

  /**
   * Gets the number of $ORES tokens for the specific level
   */
  function oresTokenForLevel(uint256 level) public view returns (uint256) {}

  /**
   * Gets the number of $KLAYE tokens for the specific level
   */
  function klayeTokenForCoolDown(uint256 level) public view returns (uint256) {}

  /**
   * checks if a token is a Marines
   * @param tokenId the ID of the token to check
   * @return marine - whether or not a token is a Marines
   */
  function isMarine(uint256 tokenId)
    external
    view
    override
    blockIfChangingToken(tokenId)
    returns (bool)
  {
    // Sneaky aliens will be slain if they try to peep this after mint. Nice try.
    IMnA.MarineAlien memory s = tokenTraits[tokenId];
    return s.isMarine;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external requireContractsSet onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /**
   * enables an address to mint / burn
   * @param addr the address to enable
   */
  function addAdmin(address addr) external onlyOwner {
    admins[addr] = true;
  }

  /**
   * disables an address from minting / burning
   * @param addr the address to disbale
   */
  function removeAdmin(address addr) external onlyOwner {
    admins[addr] = false;
  }

  function getTokenTraits(uint256 tokenId)
    external
    view
    override
    blockIfChangingAddress
    blockIfChangingToken(tokenId)
    returns (IMnA.MarineAlien memory)
  {
    return tokenTraits[tokenId];
  }

  function getTokenLevel(uint256 tokenId)
    external
    view
    override
    blockIfChangingAddress
    blockIfChangingToken(tokenId)
    returns (uint256)
  {
    return tokenLevels[tokenId];
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    blockIfChangingAddress
    blockIfChangingToken(tokenId)
    returns (string memory)
  {
    require(_exists(tokenId), "Token ID does not exist");
    return traits.tokenURI(tokenId);
  }

  function tokenOfOwnerByIndex(address owner, uint256 index)
    public
    view
    virtual
    override(ERC721Enumerable, IERC721Enumerable)
    blockIfChangingAddress
    returns (uint256)
  {
    require(
      admins[_msgSender()] || lastWriteAddress[owner].blockNum < block.number,
      "hmmmm what doing?"
    );
    uint256 tokenId = super.tokenOfOwnerByIndex(owner, index);
    require(
      admins[_msgSender()] || lastWriteToken[tokenId].blockNum < block.number,
      "hmmmm what doing?"
    );
    return tokenId;
  }

  function balanceOf(address owner)
    public
    view
    virtual
    override(ERC721, IERC721)
    blockIfChangingAddress
    returns (uint256)
  {
    require(
      admins[_msgSender()] || lastWriteAddress[owner].blockNum < block.number,
      "hmmmm what doing?"
    );
    return super.balanceOf(owner);
  }

  function ownerOf(uint256 tokenId)
    public
    view
    virtual
    override(ERC721, IERC721)
    blockIfChangingAddress
    blockIfChangingToken(tokenId)
    returns (address)
  {
    address addr = super.ownerOf(tokenId);
    require(
      admins[_msgSender()] || lastWriteAddress[addr].blockNum < block.number,
      "hmmmm what doing?"
    );
    return addr;
  }

  function tokenByIndex(uint256 index)
    public
    view
    virtual
    override(ERC721Enumerable, IERC721Enumerable)
    returns (uint256)
  {
    uint256 tokenId = super.tokenByIndex(index);
    require(
      admins[_msgSender()] || lastWriteToken[tokenId].blockNum < block.number,
      "hmmmm what doing?"
    );
    return tokenId;
  }

  function approve(address to, uint256 tokenId)
    public
    virtual
    override(ERC721, IERC721)
    blockIfChangingToken(tokenId)
  {
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId)
    public
    view
    virtual
    override(ERC721, IERC721)
    blockIfChangingToken(tokenId)
    returns (address)
  {
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address operator, bool approved)
    public
    virtual
    override(ERC721, IERC721)
    blockIfChangingAddress
  {
    super.setApprovalForAll(operator, approved);
  }

  function isApprovedForAll(address owner, address operator)
    public
    view
    virtual
    override(ERC721, IERC721)
    blockIfChangingAddress
    returns (bool)
  {
    return super.isApprovedForAll(owner, operator);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override(ERC721, IERC721) blockIfChangingToken(tokenId) {
    super.safeTransferFrom(from, to, tokenId);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public virtual override(ERC721, IERC721) blockIfChangingToken(tokenId) {
    super.safeTransferFrom(from, to, tokenId, _data);
  }

  function onERC721Received(
    address,
    address from,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}
