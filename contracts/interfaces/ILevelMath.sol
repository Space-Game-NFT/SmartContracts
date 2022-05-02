// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ILevelMath {
  struct LevelEpoch {
    uint256 oresToken;
    uint256 coolDownTime;
    uint256 klayeToSkip;
    uint256 klayePerDay;
    uint256 maxRewardDuration;
  }

  function getLevelEpoch(uint256 level)
    external
    view
    returns (LevelEpoch memory);
}
