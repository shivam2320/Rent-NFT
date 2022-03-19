//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract RentNFT {

  uint256 counter = 0;
  uint256 weiTOeth = 10**18;

  enum State {
    Available,
    Borrowed,
    Delisted
  }

  struct nftInfo {
    address lenderAddress;
    address nftAddress;
    uint256 tokenId;
    uint256 lendingId;
    uint256 dailyRate;
    uint256 collateral;
    uint256 maxBorrowTime;
    State nftState;
  }

  struct borrowerInfo {
    address payable borrowerAddress;
    uint256 totalAmountPaid;
    uint256 borrowedFor;
    uint256 deadline;
  }

  mapping(uint256 => nftInfo) public nftMapping;

  mapping(uint256 => borrowerInfo) borrowerDetails;

  modifier onlyNftOwner(address _nftAddress, uint256 _tokenId) {
    require(IERC721(_nftAddress).ownerOf(_tokenId) == msg.sender, "You are not NFT owner");
    _;
  }

  modifier onlyLender(uint256 _id) {
    require(nftMapping[_id].lenderAddress == msg.sender, "only owner is allowed");
    _;
  }

  modifier onlyBorrower(uint256 _id) {
    require(borrowerDetails[_id].borrowerAddress == msg.sender, "only borrower is allowed");
    _;
  }

  modifier isAvailabe(uint256 _id) {
    require(nftMapping[_id].nftState == State.Available, "NFT is not available");
    _;
  }

  modifier isBorrowed(uint256 _id) {
    require(nftMapping[_id].nftState == State.Borrowed, "NFT is not borrowed");
    _;
  }

  function lendNFT(address _nft, uint256 _tokenId, uint256 _dailyRate, uint256 _maxBorrowTime, uint256 _collateral) external onlyNftOwner(_nft, _tokenId) returns (uint256) {

    nftInfo memory newNFT;
    uint256 currentCollateral = _collateral * weiTOeth;
    uint256 currentdailyrate = _dailyRate * weiTOeth;
    newNFT = nftInfo(msg.sender, _nft, _tokenId, counter, _dailyRate, currentCollateral, _maxBorrowTime, State.Available);
    nftMapping[counter] = newNFT;
    IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);

    counter++;

    return counter;
  }

  function borrowNFT(uint256 _lendingId, uint256 _numOfDays) payable external isAvailabe(_lendingId) {
    require( borrowerDetails[_lendingId].borrowerAddress == address(0), "NFT already borrowed");
    require(msg.value >= nftMapping[_lendingId].collateral + _numOfDays*nftMapping[_lendingId].dailyRate, "Pay required collateral and fees");
    require(nftMapping[_lendingId].maxBorrowTime >= _numOfDays, "Exceeding borrow limit");
    IERC721(nftMapping[_lendingId].nftAddress).safeTransferFrom(address(this), msg.sender, nftMapping[_lendingId].tokenId);

    borrowerInfo memory newBorrower;
    newBorrower = borrowerInfo(payable(msg.sender), msg.value, _numOfDays, block.timestamp + _numOfDays*86400);
    borrowerDetails[_lendingId] = newBorrower;

    nftMapping[_lendingId].nftState = State.Borrowed;
  }

  function returnNft(uint256 _lendingId) external isBorrowed(_lendingId) onlyBorrower(_lendingId) {
    require(borrowerDetails[_lendingId].borrowerAddress == msg.sender, "You have not borrowed the NFT");
    require(borrowerDetails[_lendingId].deadline >= block.timestamp, "Deadline has passed");

    IERC721(nftMapping[_lendingId].nftAddress).safeTransferFrom(msg.sender, address(this), nftMapping[_lendingId].tokenId);

    uint256 returnCollateral = nftMapping[_lendingId].collateral;
    payable(msg.sender).transfer(returnCollateral);

    nftMapping[_lendingId].nftState = State.Available;
    borrowerDetails[_lendingId].borrowerAddress == address(0); 
  }

  function stopLending(uint256 _lendingId) external onlyLender(_lendingId) {
    IERC721(nftMapping[_lendingId].nftAddress).approve(msg.sender, nftMapping[_lendingId].tokenId);

    IERC721(nftMapping[_lendingId].nftAddress).transferFrom(address(this), msg.sender, nftMapping[_lendingId].tokenId);

    uint amountToPay = (borrowerDetails[_lendingId].totalAmountPaid-nftMapping[_lendingId].collateral]);
    payable(msg.sender).transfer(amountToPay);

    nftMapping[_lendingId].nftState = State.Delisted;
  }

  function claimCollateral(uint256 _lendingId) external onlyLender(_lendingId){
    require(borrowerDetails[_lendingId].deadline < block.timestamp, "Deadline has not yet passed");
    payable(msg.sender).transfer(nftMapping[_lendingId].collateral);
  }

  function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

}