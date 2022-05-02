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

contract Spidox is Ownable, ERC721A, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    bool private _isActive = false;
    bytes32 public merkleRoot;
    uint256 public MAX_MINT = 6969;
    uint256 public maxCountPerClaim = 1;
    uint256 public totalMinted = 0;
    string private _tokenBaseURI = "";

    mapping(address => bool) public claimedAccounts;

    modifier onlyActive() {
        require(_isActive && totalMinted < MAX_MINT, "not active");
        _;
    }

    constructor(bytes32 _merkleRoot, uint256 _maxBatchMintSize)
        ERC721A("SPIDOX", "SPIDOX", _maxBatchMintSize)
    {
        merkleRoot = _merkleRoot;
    }

    function claim(uint256 numberOfTokens, bytes32[] calldata merkleProof)
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
        require(numberOfTokens < MAX_MINT.sub(totalMinted), "not enough nfts");
        require(!claimedAccounts[msg.sender], "already claimed");
        require(
            isWhiteList(msg.sender, merkleProof),
            "Only whitelisted account can claim"
        );
        _safeMint(msg.sender, 1);
        totalMinted++;
        claimedAccounts[msg.sender] = true;
    }

    function isWhiteList(address account, bytes32[] calldata merkleProof)
        public
        view
        returns (bool)
    {
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(merkleProof, merkleRoot, node);
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

    function setMaxCountPerClaim(uint256 _maxCountPerClaim) public onlyOwner {
        maxCountPerClaim = _maxCountPerClaim;
    }

    function setMaxMint(uint256 _maxMint) public onlyOwner {
        MAX_MINT = _maxMint;
    }

    function setTokenBaseURI(string memory URI) external onlyOwner {
        _tokenBaseURI = URI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setActive(bool _active) external onlyOwner {
        _isActive = _active;
    }

    receive() external payable {}
}
