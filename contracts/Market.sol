// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner;
  uint256 listingPrice = 0.025 ether;
  mapping(uint=>mapping(uint=>address payable)) itemOwnerHistoryList;
  
  constructor() {
    owner = payable(msg.sender);
  }

  
  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
    uint256 saleCount;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold,
    uint256 saleCount
  );
  

  /* Returns the listing price of the contract */
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }
  
  /* Places an item for sale on the marketplace */
  function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least 1 wei");
    require(msg.value == listingPrice, "Price must be equal to listing price");


    _itemIds.increment();
    uint256 itemId = _itemIds.current();

    itemOwnerHistoryList[itemId][0] = payable(msg.sender) ;

    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false,
      0
    ); 

     emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false,
      0
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function createMarketSale(
    address nftContract,
    uint256 itemId
    ) public payable nonReentrant {
    idToMarketItem[itemId].saleCount=idToMarketItem[itemId].saleCount+1; //numberOftimes item is sold

    uint price = idToMarketItem[itemId].price;
    uint tokenId = idToMarketItem[itemId].tokenId;

    require(msg.value == price, "Please submit the asking price in order to complete the purchase");
    
    uint currentSale = idToMarketItem[itemId].saleCount;
    uint remainingFunds = msg.value;
    while (currentSale>=0){
        if(currentSale==0){
            itemOwnerHistoryList[itemId][currentSale].transfer((remainingFunds));    
        }
        itemOwnerHistoryList[itemId][currentSale].transfer((remainingFunds*4/5));
        remainingFunds -= (remainingFunds*4/5);
        currentSale -= 1;
    }   
    /*if(idToMarketItem[itemId].saleCount==1)
    {
    idToMarketItem[itemId].seller.transfer(msg.value);
    }
    if(idToMarketItem[itemId].saleCount==2)
    {
    idToMarketItem[itemId].seller.transfer((msg.value*4/5));
    idToMarketItem[itemId].firstOwner.transfer(msg.value*1/5);
     console.log("The share of 2nd owner", msg.value*4/5);
     console.log("The share of 1st owner", msg.value*1/5);
    }
    if(idToMarketItem[itemId].saleCount==3){
      idToMarketItem[itemId].seller.transfer((msg.value*4/5));
      idToMarketItem[itemId].firstOwner.transfer((msg.value*1/5*4/5));
      idToMarketItem[itemId].secondOwner.transfer((msg.value*1/5*1/5));
      console.log("The share of 3rd owner", msg.value*4/5);
      console.log("The share of 2nd owner", msg.value*4/5*1/5);
      console.log("The share of 1st owner", msg.value*1/5*1/5);
    }*/


    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);  //Ownership transfer
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();
    payable(owner).transfer(listingPrice);
    idToMarketItem[itemId].saleCount+=1;
    itemOwnerHistoryList[itemId][idToMarketItem[itemId].saleCount]=payable(msg.sender);
  }
  
  function resellItem(
    address nftContract,
    uint256 tokenId,
    uint256 itemId,
    uint256 price
  ) public payable{
    if(idToMarketItem[itemId].saleCount==1){
      idToMarketItem[itemId].secondOwner= payable(msg.sender);
    }
    if(idToMarketItem[itemId].saleCount==2){
      idToMarketItem[itemId].thirdOwner= payable(msg.sender);
    }
    idToMarketItem[itemId].seller= payable(msg.sender);
    idToMarketItem[itemId].owner = payable(address(0));
    idToMarketItem[itemId].sold = false;
    idToMarketItem[itemId].price = price;
    _itemsSold.decrement();
    console.log("In contract");
    console.log("Sender", msg.sender);
    console.log("Token id",tokenId);
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
  }

  /* Returns all unsold market items */
  function fetchMarketItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if(idToMarketItem[i+1].owner==address(0))
     {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
     } 
    }
    return items;
  }

  /* Returns onlyl items that a user has purchased */
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has created */
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

}