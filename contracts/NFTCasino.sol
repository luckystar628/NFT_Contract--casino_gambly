// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTCasino {

    address payable contractOwner;

    mapping (uint256 => NFTDeposit) nftDeposits;
    mapping (uint256 => NFTOffer) nftOffers;

    uint contractProfits;

    /** Contract deployer will be the owner who can withdraw the profits */
    constructor() {
        contractOwner = payable(msg.sender);
    }

    /** The first wallet to deposit an NFT, it will have to wait for an offer */
    struct NFTDeposit {
        address nftContract;
        uint256 tokenId;
        address owner;
        bool matchPlayed;
        address newOwner;
    }

    /** An offer to start a game with a previously deposited NFT */
    struct NFTOffer {
        address nftContract;
        uint256 tokenId;
        address owner;
        uint256 toDepositID;
        bool matchPlayed;
        address newOwner;
    }

    /** Create a deposit */
    function createDeposit(address contractAddress, uint256 tokenId) external{
        IERC721 nftContractInstance = IERC721(contractAddress);

        // Security checks
        require(nftContractInstance.ownerOf(tokenId) == msg.sender, "Only the NFT owner can create a deposit");
        require(nftContractInstance.getApproved(tokenId) == address(this) || nftContractInstance.isApprovedForAll(msg.sender, address(this)), "NFT must be approved to be deposited");

        // NFT transfer from owner to contract
        nftContractInstance.safeTransferFrom(msg.sender, address(this), tokenId);
        
        // NFTDeposit creation
        uint256 depositID = uint256(keccak256(abi.encode(msg.sender, tokenId, block.timestamp, block.difficulty)));
        nftDeposits[depositID] = NFTDeposit({
            nftContract: address(contractAddress),
            tokenId: tokenId,
            owner: msg.sender,
            matchPlayed: false,
            newOwner: address(0)
        });
    }

    /** Cancel a deposit & withdraw the NFT */
    function cancelDeposit(uint256 depositID) external {
        NFTDeposit storage details = nftDeposits[depositID];
        IERC721 nftContractInstance = IERC721(details.nftContract);

        // Security checks
        require(details.matchPlayed == false, "NFT already gambled");
        require(msg.sender == details.owner, "Only the owner can cancel the deposit");

        // NFT withdrawal
        nftContractInstance.safeTransferFrom(address(this), details.owner, details.tokenId);

        // NFTDeposit object removal
        delete nftDeposits[depositID];
    }

    /** Create an offer */
    function createOffer(address nftContract, uint256 tokenId, uint256 toDepositID) external {
        IERC721 nftContractInstance = IERC721(nftContract);

        // Security checks
        require(nftContractInstance.ownerOf(tokenId) == msg.sender, "Only the NFT owner can create an offer");
        require(nftContractInstance.getApproved(tokenId) == address(this) || nftContractInstance.isApprovedForAll(msg.sender, address(this)), "NFT must be approved to be offered");

        // NFT transfer from owner to contract
        nftContractInstance.safeTransferFrom(msg.sender, address(this), tokenId, abi.encode("NFTCASINO.ETH TRANSFER"));

        // NFTOffer creation
        uint256 offerID = uint256(keccak256(abi.encode(msg.sender, tokenId, block.timestamp, block.difficulty)));
        nftOffers[offerID] = NFTOffer({
            nftContract: nftContract,
            tokenId: tokenId,
            owner: msg.sender,
            toDepositID: toDepositID,
            matchPlayed: false,
            newOwner: address(0)
        });
    }

    /** Cancel an offer & withdraw the NFT */
    function cancelOffer(uint256 offerID) external {
        NFTOffer storage details = nftOffers[offerID];
        IERC721 nftContractInstance = IERC721(details.nftContract);

        //Security checks
        require(details.matchPlayed == false, "NFT already gambled");
        require(msg.sender == details.owner, "Only the owner can cancel the offer");

        // NFT withdrawal
        nftContractInstance.safeTransferFrom(address(this), details.owner, details.tokenId);

        // NFTOffer object removal
        delete nftOffers[offerID];
    }

    /** Accept an offer & randomly select a winner */
    function acceptOffer(uint256 depositID, uint256 offerID) external {
        NFTDeposit storage depositDetails = nftDeposits[depositID];
        NFTOffer storage offerDetails = nftOffers[offerID];

        // Security checks
        require(depositDetails.matchPlayed == false, "NFT already gambled");
        require(nftDeposits[depositID].owner == msg.sender, "Only the owner can accept the offer");

        // TODO: Random Winner Selection using Chainlink oracles

    }

    /** Withdraw both NFTs & pay the fee to the contract owner */
    function withdrawPrize(uint256 depositID, uint256 offerID) external payable {
        NFTDeposit storage depositDetails = nftDeposits[depositID];
        NFTOffer storage offerDetails = nftOffers[offerID];

        IERC721 depositNFTContractInstance = IERC721(depositDetails.nftContract);
        IERC721 offerNFTContractInstance = IERC721(offerDetails.nftContract);

        // Security checks
        require(msg.value >= .001 ether, "You must pay at least 0.001 ether");
        require(depositDetails.newOwner == msg.sender, "You can't withdraw the NFT");
        require(offerDetails.newOwner == msg.sender, "You can't withdraw the NFT");

        // NFTs transfer from contract to owner
        depositNFTContractInstance.safeTransferFrom(address(this), msg.sender, depositDetails.tokenId);
        offerNFTContractInstance.safeTransferFrom(address(this), msg.sender, offerDetails.tokenId);
    }

    /** Allow the contract owner to withdraw all the ETH profits */
    function withdrawContractProfits() external onlyContractOwner {
        // Profits transfer from contract to owner
        contractOwner.transfer(address(this).balance);
    }

    /** Only contractOwner modifier */
    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only the contract owner can withdraw profits");
        _;
    }

    /** Interface required to handle NFT deposits */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        //TODO: Accidental NFT Transfer withdraw method
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    /** Get the contract owner address */
    function getContractOwner() public view returns (address) {
        return contractOwner;
    }
}