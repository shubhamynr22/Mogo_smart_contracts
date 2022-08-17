// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721, AccessControl, ReentrancyGuard {
    using Strings for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant Owner_ROLE = keccak256("Owner_ROLE");

    address owner;
    bool public paused = false;

    uint256 tokenID;

    mapping(uint256 => string) tokenMetadataCID;

    modifier onlyOwner() {
        require(hasRole(Owner_ROLE, msg.sender), "Caller is not a owner");
        _;
    }

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _setupRole(Owner_ROLE, _owner);
    }

    // public
    function mint(address _to, string memory _uri) external nonReentrant {
        require(!paused);
        tokenID = tokenID + 1;

        _safeMint(_to, tokenID);
        tokenMetadataCID[tokenID] = _uri;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return tokenMetadataCID[tokenId];
    }

    function pause(bool _state) external nonReentrant onlyOwner {
        paused = _state;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
