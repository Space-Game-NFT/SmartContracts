// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import "./libraries/ERC721A.sol";


contract FounderPass is Ownable, ERC721A, ReentrancyGuard {
    using SafeMath for uint256;
    using Strings for uint256;
    using SafeERC20 for IERC20;
   
    bool private _isActive = false;
    bool public isPublicSale = false;
    bool public isTransferLocked = true;
    bytes32 public merkleRoot;
    address public weth;

    uint256 public constant MAX_MINT = 6969;
    uint256 public constant maxCountPerAccountPre = 3;
    uint256 public constant maxCountPerAccountPublic = 6;

    uint256 public maxCountPerClaim = 30;
    uint256 public presalePrice = 0.055 ether;
    uint256 public publicsalePrice = 0.075 ether;

    uint256 public totalMinted = 0;
    string private _tokenBaseURI = "";

    // Mapping from owner to list of Minted token IDs
    mapping(address => uint256) private _preMintedTokens;
    mapping(address => uint256) private _publicMintedTokens;

    modifier onlyActive() {
        require(_isActive && totalMinted < MAX_MINT, 'not active');
        _;
    }

    constructor(bytes32 _merkleRoot, uint256 _maxBatchMintSize, address _weth) ERC721A("FounderPass", "FP", _maxBatchMintSize) {
        merkleRoot = _merkleRoot;
        weth = _weth;
    }

    function mint(uint256 numberOfTokens, bytes32[] calldata merkleProof) external payable onlyActive nonReentrant() {
        require(numberOfTokens > 0, "zero count");
        require(numberOfTokens <= maxCountPerClaim, "exceeded max limit per claim");
        require(numberOfTokens <= MAX_MINT.sub(totalMinted), "not enough nfts");
        require(availableClaimCount(msg.sender, merkleProof) >= numberOfTokens, "insufficient available");

        uint256 costForMinting = costForMint(numberOfTokens);
        // transfer cost for mint to owner address
        IERC20(weth).safeTransferFrom(msg.sender, owner(), costForMinting);
        _safeMint(msg.sender, numberOfTokens);
        totalMinted = totalMinted + numberOfTokens;

        if(isPublicSale) {
            _publicMintedTokens[msg.sender] = _publicMintedTokens[msg.sender].add(numberOfTokens);
        } else {
            _preMintedTokens[msg.sender] = _preMintedTokens[msg.sender].add(numberOfTokens);
        }
    }

    function costForMint(uint256 _numToMint) public view returns(uint256) {
        return (isPublicSale ? publicsalePrice : presalePrice).mul(_numToMint);
    }

    function availableClaimCount(address account, bytes32[] calldata merkleProof) public view returns(uint256) {
        if(!_isActive) {
            return 0;
        }
        if(!isPublicSale) {
            if(!isWhiteList(account, merkleProof)) {
                return 0;
            }
            return _preMintedTokens[account] >= maxCountPerAccountPre ? 0 : maxCountPerAccountPre.sub(_preMintedTokens[account]);
        }
        else {
            return _publicMintedTokens[account] >= maxCountPerAccountPublic ? 0 : maxCountPerAccountPublic.sub(_publicMintedTokens[account]);
        }
    }   


    function isWhiteList(address account, bytes32[] calldata merkleProof) public view returns(bool) {
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(merkleProof, merkleRoot, node);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721A) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        require(!isTransferLocked, "Transfer Locked!");
    }    
    
    /////////////////////////////////////////////////////////////
    //////////////////   Admin Functions ////////////////////////
    /////////////////////////////////////////////////////////////
    function startPresale() external onlyOwner {
        _isActive = true;
        isPublicSale = false;
    }

    function startPublicSale() external onlyOwner {
        _isActive = true;
        isPublicSale = true;
    }

    function endSale() external onlyOwner {
        _isActive = false;
    }

    function setTokenBaseURI(string memory URI) external onlyOwner {
        _tokenBaseURI = URI;
    }

    function setPresalePrice(uint _price) external onlyOwner {
        presalePrice = _price;
    }

    function setPublicsalePrice(uint _price) external onlyOwner {
        publicsalePrice = _price;
    }

    function setMaxCountPerClaim(uint _count) external onlyOwner {
        maxCountPerClaim = _count;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setTransferLocked(bool _isTransferLocked) external onlyOwner {
        isTransferLocked = _isTransferLocked;
    }

    receive() external payable {}

    function _safeTransferETH(address to, uint256 value) internal returns(bool) {
		(bool success, ) = to.call{value: value}(new bytes(0));
		return success;
    }

}