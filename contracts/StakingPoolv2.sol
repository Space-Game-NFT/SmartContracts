// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMnAGame.sol";
import "./interfaces/IMnAv2.sol";
import "./interfaces/IKLAYE.sol";
import "./interfaces/ILevelMath.sol";
import "./interfaces/IORES.sol";

contract StakingPoolv2 is
  Initializable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  IERC721Receiver,
  PausableUpgradeable
{
  // maximum rank for a Marine/Alien
  uint8 public constant MAX_RANK = 4;

  // struct to store a stake information
  struct Stake {
    uint256 tokenId;
    address owner;
    uint256 value;
    uint256 lastClaimTime;
    uint256 startTime;
    uint256 stakedDuration;
  }

  uint256 private totalRankStaked;

  event TokenStaked(
    uint256 indexed tokenId,
    address indexed owner,
    bool isMarine,
    uint256 stakedDuration,
    uint256 value
  );

  event MarineClaimed(
    uint256 indexed tokenId,
    bool indexed unstaked,
    uint256 earned
  );
  event AlienClaimed(
    uint256 indexed tokenId,
    bool indexed unstaked,
    uint256 earned
  );

  // reference to the MnAv2 NFT contract
  IMnAv2 public mnaNFT;
  // reference to the $KLAYE contract for minting $KLAYE earnings
  IKLAYE public klayeToken;
  // reference to LevelMath
  ILevelMath public levelMath;
  // reference to oresToken
  IORES public oresToken;

  // maps tokenId to stake
  mapping(uint256 => Stake) public marinePool;
  // maps rank to all Alien staked with that rank
  mapping(uint256 => Stake[]) public alienPool;
  // tracks location of each Alien in AlienPool
  mapping(uint256 => uint256) private alienPoolIndices;
  // any rewards distributed when no aliens are staked
  uint256 private unaccountedRewards;
  // amount of $KLAYE due for each rank point staked
  uint256 private klayePerRank;

  // marines must have 2 days worth of $KLAYE to unstake or else they're still guarding the marine pool
  uint256 public constant MINIMUM_TO_EXIT = 2 days;
  // aliens take a 20% tax on all $KLAYE claimed
  uint256 public constant KLAYE_CLAIM_TAX_PERCENTAGE = 20;
  // penalty fee for unstaking
  uint256 public UNSTAKE_KLAYE_AMOUNT = 3 ether;

  // amount of $KLAYE earned so far
  uint256 public totalKLAYEEarned;
  // the last time $KLAYE was claimed
  uint256 private lastClaimTimestamp;

  // emergency rescue to allow unstaking without any checks but without $KLAYE
  bool public rescueEnabled;

  // store levels for token ids
  mapping(uint256 => uint256) private tokenLevels;

  function initialize() public initializer {
    __Pausable_init_unchained();
    __ReentrancyGuard_init_unchained();
    __Ownable_init_unchained();
    _pause();
  }

  /** CRITICAL TO SETUP */

  modifier requireContractsSet() {
    require(
      address(mnaNFT) != address(0) &&
        address(klayeToken) != address(0) &&
        address(oresToken) != address(0) &&
        address(levelMath) != address(0),
      "Contracts not set"
    );
    _;
  }

  function setContracts(
    address _mnaNFT,
    address _klaye,
    address _ores,
    address _levelMath
  ) external onlyOwner {
    mnaNFT = IMnAv2(_mnaNFT);
    klayeToken = IKLAYE(_klaye);
    oresToken = IORES(_ores);
    levelMath = ILevelMath(_levelMath);
  }

  /** STAKING */

  /**
   * adds Marines and Aliens to the MarinePool and AlienPool
   * @param account the address of the staker
   * @param tokenIds the IDs of the Marines and Aliens to stake
   */
  function addManyToMarinePoolAndAlienPool(
    address account,
    uint256[] calldata tokenIds
  ) external nonReentrant {
    require(tx.origin == _msgSender(), "Only EOA");
    require(account == tx.origin, "account to sender mismatch");
    uint256 tokenId;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(
        mnaNFT.ownerOf(tokenId) == _msgSender(),
        "You don't own this token"
      );
      uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
      require(
        canStake(tokenId, tokenLevel),
        "can't stake. upgrade level first"
      );
      mnaNFT.transferFrom(_msgSender(), address(this), tokenId);

      if (mnaNFT.isMarine(tokenId))
        _addMarineToMarinePool(account, tokenId, tokenLevel);
      else _addAlienToAlienPool(account, tokenId, tokenLevel);
    }
  }

  /**
   * adds a single Marine to the MarinePool
   * @param account the address of the staker
   * @param tokenId the ID of the Marine to add to the MarinePool
   */
  function _addMarineToMarinePool(
    address account,
    uint256 tokenId,
    uint256 level
  ) internal whenNotPaused {
    Stake storage stake = marinePool[tokenId];
    stake.tokenId = tokenId;
    stake.owner = account;
    stake.startTime = block.timestamp;
    stake.lastClaimTime = block.timestamp;
    uint256 storedLevel = tokenLevels[tokenId];
    if (level == storedLevel) {
      stake.stakedDuration = stake.stakedDuration;
    } else {
      stake.stakedDuration = 0;
    }

    stake.value = 0;
    tokenLevels[tokenId] = level;
    emit TokenStaked(tokenId, account, true, stake.stakedDuration, 0);
  }

  /**
   * adds a single Alien to the AlienPool
   * @param account the address of the staker
   * @param tokenId the ID of the Alien to add to the AlienPool
   */
  function _addAlienToAlienPool(
    address account,
    uint256 tokenId,
    uint256 level
  ) internal {
    uint8 rank = _rankForAlien(tokenId);
    totalRankStaked += rank; // Portion of earnings ranges from 4 to 1
    alienPoolIndices[tokenId] = alienPool[rank].length; // Store the location of the alien in the AlienPool
    alienPool[rank].push(
      Stake({
        tokenId: tokenId,
        owner: account,
        value: klayePerRank,
        startTime: block.timestamp,
        lastClaimTime: block.timestamp,
        stakedDuration: 0
      })
    ); // Add the alien to the AlienPool
    if(tokenLevels[tokenId] != level) {
      tokenLevels[tokenId] = level;
    }
    emit TokenStaked(tokenId, account, false, 0, klayePerRank);
  }

  /** CLAIMING / UNSTAKING */

  /**
   * realize $KLAYE earnings and optionally unstake tokens from the MarinePool / AlienPool
   * to unstake a Marine it will require it has 2 days worth of $KLAYE unclaimed
   * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
  function claimManyFromMarinePoolAndAlienPool(
    uint256[] calldata tokenIds,
    bool unstake
  ) public whenNotPaused nonReentrant {
    require(tx.origin == _msgSender(), "Only EOA");
    uint256 owed = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenLevel = mnaNFT.getTokenLevel(tokenIds[i]);
      if (mnaNFT.isMarine(tokenIds[i])) {
        owed += _claimMarineFromMarinePool(tokenIds[i], unstake, tokenLevel);
      } else {
        owed += _claimAlienFromAlienPool(tokenIds[i], unstake, tokenLevel);
      }
    }
    klayeToken.updateOriginAccess();
    if (owed == 0) {
      return;
    }
    klayeToken.mint(_msgSender(), owed);
  }

  /**
   * realize $KLAYE earnings for a single Marine and optionally unstake it
   * if not unstaking, pay a 20% tax to the staked Aliens
   * if unstaking, there is a 50% chance all $KLAYE is stolen
   * @param tokenId the ID of the Marines to claim earnings from
   * @param unstake whether or not to unstake the Marines
   * @return owed - the amount of $KLAYE earned
   */
  function _claimMarineFromMarinePool(uint256 tokenId, bool unstake, uint256 level)
    internal
    returns (uint256 owed)
  {
    Stake storage stake = marinePool[tokenId];
    require(stake.owner == _msgSender(), "Don't own the given token");
    owed = calculateRewards(tokenId);

    _payAlienTax((owed * KLAYE_CLAIM_TAX_PERCENTAGE) / 100); // percentage tax to staked aliens
    owed = (owed * (100 - KLAYE_CLAIM_TAX_PERCENTAGE)) / 100; // remainder goes to Marine owner
    stake.lastClaimTime = block.timestamp;

    if (unstake) {
      // TODO Should take unstake amount in $KLAYE
      require(
        owed >= UNSTAKE_KLAYE_AMOUNT,
        "Unstake amount is smaller than the penalty amount"
      );
      owed = owed - UNSTAKE_KLAYE_AMOUNT;

      uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
      if (tokenLevel >= 69) tokenLevel = 69;
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );

      uint256 passedDuration = block.timestamp -
        stake.startTime +
        stake.stakedDuration;
      stake.stakedDuration = passedDuration > levelEpoch.maxRewardDuration
        ? levelEpoch.maxRewardDuration
        : passedDuration;
      stake.owner = address(0);
      
      if(tokenLevels[tokenId] != tokenLevel) {
        tokenLevels[tokenId] = tokenLevel;
      }

      klayeToken.mint(address(this), UNSTAKE_KLAYE_AMOUNT);
      klayeToken.burn(address(this), UNSTAKE_KLAYE_AMOUNT);

      // Always transfer last to guard against reentrance
      mnaNFT.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Marine
    }

    emit MarineClaimed(tokenId, unstake, owed);
  }

  /**
   * realize $KLAYE earnings for a single Alien and optionally unstake it
   * Aliens earn $KLAYE proportional to their rank
   * @param tokenId the ID of the Alien to claim earnings from
   * @param unstake whether or not to unstake the Alien
   * @return owed - the amount of $KLAYE earned
   */
  function _claimAlienFromAlienPool(uint256 tokenId, bool unstake, uint256 level)
    internal
    returns (uint256 owed)
  {
    require(mnaNFT.ownerOf(tokenId) == address(this), "Doesn't own token");
    uint8 rank = _rankForAlien(tokenId);
    Stake memory stake = alienPool[rank][alienPoolIndices[tokenId]];
    require(stake.owner == _msgSender(), "Doesn't own token");
    owed = calculateRewards(tokenId);
    if (unstake) {
      // TODO Should take unstake amount in $KLAYE
      require(
        owed >= UNSTAKE_KLAYE_AMOUNT,
        "Unstake amount is smaller than the penalty amount"
      );
      owed = owed - UNSTAKE_KLAYE_AMOUNT;

      totalRankStaked -= rank; // Remove rank from total staked
      Stake memory lastStake = alienPool[rank][alienPool[rank].length - 1];
      alienPool[rank][alienPoolIndices[tokenId]] = lastStake; // Shuffle last Alien to current position
      alienPoolIndices[lastStake.tokenId] = alienPoolIndices[tokenId];
      alienPool[rank].pop(); // Remove duplicate
      klayeToken.mint(address(this), UNSTAKE_KLAYE_AMOUNT);
      klayeToken.burn(address(this), UNSTAKE_KLAYE_AMOUNT);
      delete alienPoolIndices[tokenId]; // Delete old mapping
      // Always remove last to guard against reentrance
      mnaNFT.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Alien
    } else {
      alienPool[rank][alienPoolIndices[tokenId]] = Stake({
        tokenId: tokenId,
        owner: _msgSender(),
        startTime: stake.startTime,
        value: klayePerRank,
        lastClaimTime: block.timestamp,
        stakedDuration: 0
      }); // reset stake
      if(tokenLevels[tokenId] != level) {
        tokenLevels[tokenId] = level;
      }
    }
    emit AlienClaimed(tokenId, unstake, owed);
  }

  /**
   * Upgrades levels of tokens to get rewards continuosly
   */
  function upgradeLevel(uint256[] calldata tokenIds) external whenNotPaused {
    claimManyFromMarinePoolAndAlienPool(tokenIds, false);

    uint256 totalOresToken = 0;
    for (uint256 index = 0; index < tokenIds.length; index++) {
      uint256 tokenId = tokenIds[index];
      uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );
      totalOresToken += levelEpoch.oresToken;
    }
    if (totalOresToken > 0) {
      oresToken.transferFrom(_msgSender(), address(this), totalOresToken);
    }

    IERC20(address(oresToken)).approve(address(mnaNFT), totalOresToken);
    mnaNFT.upgradeLevel(tokenIds);

    for (uint256 index = 0; index < tokenIds.length; index++) {
      uint256 tokenId = tokenIds[index];
      Stake storage stake = marinePool[tokenId];
      stake.startTime = block.timestamp;
      stake.lastClaimTime = block.timestamp;
      stake.stakedDuration = 0;
      tokenLevels[tokenId]++;
    }
  }

  /**
   * emergency unstake tokens
   * @param tokenIds the IDs of the tokens to claim earnings from
   */
  function rescue(uint256[] calldata tokenIds) external nonReentrant {
    require(rescueEnabled, "RESCUE DISABLED");
    uint256 tokenId;
    Stake memory stake;
    Stake memory lastStake;
    uint8 rank;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      if (mnaNFT.isMarine(tokenId)) {
        stake = marinePool[tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        stake.stakedDuration =
          stake.stakedDuration -
          stake.lastClaimTime +
          stake.startTime;
        mnaNFT.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Marines
        emit MarineClaimed(tokenId, true, 0);
      } else {
        rank = _rankForAlien(tokenId);
        stake = alienPool[rank][alienPoolIndices[tokenId]];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        totalRankStaked -= rank; // Remove Rank from total staked
        lastStake = alienPool[rank][alienPool[rank].length - 1];
        alienPool[rank][alienPoolIndices[tokenId]] = lastStake; // Shuffle last Alien to current position
        alienPoolIndices[lastStake.tokenId] = alienPoolIndices[tokenId];
        alienPool[rank].pop(); // Remove duplicate
        delete alienPoolIndices[tokenId]; // Delete old mapping
        mnaNFT.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Alien
        emit AlienClaimed(tokenId, true, 0);
      }
    }
  }

  /** ACCOUNTING */

  /**
   * add $KLAYE to claimable pot for the AlienPool
   * @param amount $KLAYE to add to the pot
   */
  function _payAlienTax(uint256 amount) internal {
    if (totalRankStaked == 0) {
      // if there's no staked aliens
      unaccountedRewards += amount; // keep track of $KLAYE due to aliens
      return;
    }
    // makes sure to include any unaccounted $KLAYE
    klayePerRank += (amount + unaccountedRewards) / totalRankStaked;
    unaccountedRewards = 0;
  }

  /** ADMIN */

  /**
   * allows owner to enable "rescue mode"
   * simplifies accounting, prioritizes tokens out in emergency
   */
  function setRescueEnabled(bool _enabled) external onlyOwner {
    rescueEnabled = _enabled;
  }

  /**
   * enables owner to pause / unpause contract
   */
  function setPaused(bool _paused) external requireContractsSet onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  function setUnStakeKlayeAmount(uint256 amount) external onlyOwner {
    require(amount <= 3 ether, "Exceeds maximum value");
    UNSTAKE_KLAYE_AMOUNT = amount;
  }

  /** READ ONLY */

  /**
   * gets the rank score for a Alien
   * @param tokenId the ID of the Alien to get the rank score for
   * @return the rank score of the Alien (1-4)
   */
  function _rankForAlien(uint256 tokenId) internal view returns (uint8) {
    IMnA.MarineAlien memory s = mnaNFT.getTokenTraits(tokenId);
    return s.rankIndex + 1; // rank index is 0-3, (0->4, 1->3, 2->2, 3->1)
  }

  /**
   * Determines whether `tokenId` can be staked or not.
   * Token needs to have remaining accure duration for each level to stake
   */
  function canStake(uint256 tokenId, uint256 tokenLevel)
    public
    view
    returns (bool)
  {
    if (mnaNFT.isMarine(tokenId)) {
      if (tokenLevel > 69) tokenLevel = 69;
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );
      Stake memory stake = marinePool[tokenId];
      if (tokenLevel > tokenLevels[tokenId] || stake.startTime == 0) return true;
      uint256 passedDuration = block.timestamp -
        stake.startTime +
        stake.stakedDuration;
      uint256 stakedDuration = passedDuration > levelEpoch.maxRewardDuration
        ? levelEpoch.maxRewardDuration
        : passedDuration;
      return levelEpoch.maxRewardDuration > stakedDuration;
    } else {
      return true;
    }
  }

  /**
   * Calculates how much distributes for `tokenId`
   * @param tokenId - The token id you're gonna calculate for
   */
  function calculateRewards(uint256 tokenId)
    public
    view
    returns (uint256 owed)
  {
    if (mnaNFT.isMarine(tokenId)) {
      Stake memory stake = marinePool[tokenId];
      uint256 tokenLevel = mnaNFT.getTokenLevel(tokenId);
      if (tokenLevel > 69) tokenLevel = 69;
      ILevelMath.LevelEpoch memory levelEpoch = levelMath.getLevelEpoch(
        tokenLevel
      );

      uint256 claimedDuration = stake.stakedDuration +
        stake.lastClaimTime -
        stake.startTime;

      if (levelEpoch.maxRewardDuration <= claimedDuration) {
        owed = 0;
      } else {
        uint256 leftDuration = levelEpoch.maxRewardDuration - claimedDuration;
        uint256 passedTime = block.timestamp - stake.lastClaimTime;
        uint256 rewardDuration = leftDuration > passedTime
          ? passedTime
          : leftDuration;
        owed = (rewardDuration * levelEpoch.klayePerDay) / 1 days;
      }
    } else {
      uint8 rank = _rankForAlien(tokenId);
      Stake memory stake = alienPool[rank][alienPoolIndices[tokenId]];
      owed = rank * (klayePerRank - stake.value); // Calculate portion of tokens based on Rank
    }
  }

  function onERC721Received(
    address,
    address from,
    uint256,
    bytes calldata
  ) external pure override returns (bytes4) {
    require(from == address(0x0), "Cannot send to MarinePool directly");
    return IERC721Receiver.onERC721Received.selector;
  }
}
