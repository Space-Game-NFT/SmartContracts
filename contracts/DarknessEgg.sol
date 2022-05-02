// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./libraries/ERC721A.sol";
import "./interfaces/IMnA.sol";

contract DarknessEgg is Ownable, ERC721A, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    bool private _isActive = false;
    address public ores;
    address public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public MAX_MINT = 55;

    uint256 public maxCountPerClaim = 1;
    uint256 public mintCost = 60000 ether;

    uint256 public totalMinted = 0;
    string private _tokenBaseURI = "";

    // reference to the MnA NFT contract
    IMnA public mnaNFT;

    mapping(address => bool) public claimed;

    modifier onlyActive() {
        require(_isActive && totalMinted < MAX_MINT, "not active");
        _;
    }

    constructor(
        uint256 _maxBatchMintSize,
        address _ores,
        address _mnaNFT
    ) ERC721A("Darkness Egg", "Darkness Egg", _maxBatchMintSize) {
        ores = _ores;
        mnaNFT = IMnA(_mnaNFT);
    }

    function mint(uint256 numberOfTokens, uint256 tokenId)
        external
        payable
        onlyActive
        nonReentrant
    {
        require(numberOfTokens > 0, "zero count");
        require(
            numberOfTokens <= maxCountPerClaim,
            "exceeded max limit per claim"
        );
        require(numberOfTokens <= MAX_MINT.sub(totalMinted), "not enough nfts");
        require(!claimed[msg.sender], "Already claimed");
        require(
            mnaNFT.ownerOf(tokenId) == msg.sender,
            "You don't own this token"
        );
        require(!mnaNFT.isMarine(tokenId), "You can mint with an alien");

        // transfer cost for mint to burn address
        mnaNFT.transferFrom(msg.sender, BURN_ADDRESS, tokenId);
        uint256 costForMinting = costForMint(numberOfTokens);
        IERC20(ores).safeTransferFrom(msg.sender, BURN_ADDRESS, costForMinting);
        _safeMint(msg.sender, numberOfTokens);
        totalMinted = totalMinted + numberOfTokens;

        claimed[msg.sender] = true;
    }

    function costForMint(uint256 _numToMint) public view returns (uint256) {
        return mintCost.mul(_numToMint);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function setActive(bool isActive) external onlyOwner {
        _isActive = isActive;
    }

    function setTokenBaseURI(string memory URI) external onlyOwner {
        _tokenBaseURI = URI;
    }

    function setMaxMint(uint256 _maxMint) public onlyOwner {
        MAX_MINT = _maxMint;
    }

    function setMintCost(uint256 _mintCost) public onlyOwner {
        mintCost = _mintCost;
    }

    receive() external payable {}
}
