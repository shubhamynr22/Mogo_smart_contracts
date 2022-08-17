// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTMARKETPLACE is ReentrancyGuard {
    struct FixedSale {
        address nftSeller;
        address nftBuyer;
        address erc20;
        uint256 salePrice;
    }

    mapping(address => mapping(uint256 => FixedSale)) nftContractFixedSale;
    mapping(address => mapping(uint256 => uint256)) public nftSaleStatus;

    event NftFixedSale(
        address nftContractAddress,
        address nftSeller,
        address erc20,
        uint256 tokenId,
        uint256 salePrice,
        uint256 timeOfSale
    );

    event CancelNftFixedSale(
        address nftContractAddress,
        address nftSeller,
        uint256 tokenId
    );

    event NftFixedSalePriceUpdated(
        address nftContractAddress,
        uint256 tokenId,
        uint256 updateSalePrice
    );

    event NftBuyFromFixedSale(
        address nftContractAddress,
        address nftBuyer,
        uint256 tokenId,
        uint256 nftBuyPrice
    );

    modifier isNftAlreadyInSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 0,
            "Nft already in sale"
        );
        _;
    }

    modifier isNftInFixedSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 1,
            "Nft not in fixed sale"
        );
        _;
    }

    modifier isSaleStartByOwner(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender == IERC721(_nftContractAddress).ownerOf(_tokenId),
            "You are not nft owner"
        );
        _;
    }

    modifier isSaleResetByOwner(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender ==
                nftContractFixedSale[_nftContractAddress][_tokenId].nftSeller,
            "You are not nft owner"
        );
        _;
    }

    modifier isContractApprove(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender == IERC721(_nftContractAddress).getApproved(_tokenId),
            "Nft not approved to contract"
        );
        _;
    }

    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }

    modifier buyPriceMeetSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _buyPrice
    ) {
        require(
            _buyPrice >=
                nftContractFixedSale[_nftContractAddress][_tokenId].salePrice,
            "buy Price not enough"
        );
        _;
    }

    function nftFixedSale(
        address _nftContractAddress,
        address _erc20,
        uint256 _tokenId,
        uint256 _salePrice
    )
        external
        nonReentrant
        isSaleStartByOwner(_nftContractAddress, _tokenId)
        isNftAlreadyInSale(_nftContractAddress, _tokenId)
        isContractApprove(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_salePrice)
    {
        nftContractFixedSale[_nftContractAddress][_tokenId] = FixedSale(
            msg.sender,
            address(0),
            _erc20,
            _salePrice
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 1;

        IERC721(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit NftFixedSale(
            _nftContractAddress,
            msg.sender,
            _erc20,
            _tokenId,
            _salePrice,
            block.timestamp
        );
    }

    function cancelFixedsale(address _nftContractAddress, uint256 _tokenId)
        external
        nonReentrant
        isNftInFixedSale(_nftContractAddress, _tokenId)
        isSaleResetByOwner(_nftContractAddress, _tokenId)
    {
        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        emit CancelNftFixedSale(_nftContractAddress, msg.sender, _tokenId);
    }

    function updateFixedSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateSalePrice
    )
        external
        nonReentrant
        isNftInFixedSale(_nftContractAddress, _tokenId)
        isSaleResetByOwner(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_updateSalePrice)
    {
        nftContractFixedSale[_nftContractAddress][_tokenId]
            .salePrice = _updateSalePrice;

        emit NftFixedSalePriceUpdated(
            _nftContractAddress,
            _tokenId,
            _updateSalePrice
        );
    }

    function buyFromFixedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    )
        external
        payable
        nonReentrant
        isNftInFixedSale(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_amount)
        buyPriceMeetSalePrice(_nftContractAddress, _tokenId, _amount)
    {
        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        nftContractFixedSale[_nftContractAddress][_tokenId].nftBuyer = msg
            .sender;

        _isTokenOrCoin(
            nftContractFixedSale[_nftContractAddress][_tokenId].nftSeller,
            nftContractFixedSale[_nftContractAddress][_tokenId].erc20,
            nftContractFixedSale[_nftContractAddress][_tokenId].salePrice
        );

        emit NftBuyFromFixedSale(
            _nftContractAddress,
            msg.sender,
            _tokenId,
            _amount
        );
    }

    function _tokenAmountTransfer(
        address _nftSeller,
        address _erc20,
        uint256 _buyAmount
    ) internal {
        require(
            IERC20(_erc20).transferFrom(msg.sender, address(this), _buyAmount),
            "allowance not enough"
        );
        IERC20(_erc20).transfer(_nftSeller, _buyAmount);
    }

    function _nativeAmountTransfer(address _nftSeller, uint256 _buyAmount)
        internal
    {
        (bool success, ) = _nftSeller.call{value: _buyAmount}("");
        require(success, "refund failed");
    }

    function _isTokenOrCoin(
        address _nftSeller,
        address _erc20,
        uint256 _buyAmount
    ) internal {
        if (_erc20 != address(0)) {
            _tokenAmountTransfer(_nftSeller, _erc20, _buyAmount);
        } else {
            _nativeAmountTransfer(_nftSeller, _buyAmount);
        }
    }
}
