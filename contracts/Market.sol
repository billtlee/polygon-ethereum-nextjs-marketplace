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
  uint8 royalties = 10; // percent of sale going to royalties
  uint8 royalty_a = 50; // percent of royalty going to first owner
  uint8 royalty_b = 20; // percent of royalty going to the seller
  // //implicit royalty_c = 30; // percent of royalty going to the the intermediaries

  address payable owner;
  uint256 listingPrice = 0.025 ether;

  modifier onlyOwner(){
    require(msg.sender==owner);
    _;
  }
  
  function setRoyalties(uint8 _royalties, uint8 _royalty_a, uint8 _royalty_b) external onlyOwner{
    if(_royalties<=100){
      royalties=_royalties;
    }
    if(_royalty_a<=100 && _royalty_b<=100){
      require((_royalty_a+_royalty_b)<=100);
      royalty_a=_royalty_a;
      royalty_b=_royalty_b;
    }
    else if (_royalty_a<=100){
      require((_royalty_a+royalty_b)<=100);
      royalty_a=_royalty_a;
    }
    else if (_royalty_b<=100){
      require((royalty_a+_royalty_b)<=100);
      royalty_b=_royalty_b;
    }
  }
  // this function can be called to change royalties and/or royalty_a and/or royalty_b
  // royalty_c is still implicit since it always has to be equal to 100 - royalty_a - royalty_b and this method also avoids having to check if a + b + c = 100
  // if you want to change only royalties to 20 percent call function with setRoyalties(20,101,101) and it will change only that

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
    address payable firstOwner;
    address payable secondOwner;
    address payable thirdOwner;
    uint256 saleCount;
   
  }

  // struct Auction {
  //   //uint itemId;
  //   uint  endAt;
  //   bool started;
  //   bool ended;

  //   address highestBidder;
  //   uint highestBid;
  //   uint bidCount;
  // }

  // struct BidStruct {
  //     address payable bidder;
  //     uint256 bid;
  // }
  //item 5 bid number 4
  //bids[5][4] -> Bidstruct(address, bid amount)

  // mapping (uint256 => Auction) private idToAuctionItem;
  // mapping (uint256 => mapping(uint=>BidStruct)) public bids; 
  mapping(uint256 => MarketItem) private idToMarketItem;
  mapping (uint256 => mapping(uint256=>address payable)) owners;

  /*bids[1]
    address   bid
    abc1      10
    nsn12     20
    ndasn     30
    newbidder 40
  
  accounts
    int     address
    1         abc1
    2         nsn12
    3         ndasn
    4         newbidder
  */
  

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold,
    address firstOwner,
    address secondOwner,
    address thirdOwner,
    uint saleCount
  );
  

  /* Returns the listing price of the contract */
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }
  
  // in create marketItem, add a boolean whether its onSale or onAuction (might be better to change sold to onSale)
  // if on auction, take input of time period as well, and implement start procedure in this function (maybe think of setting where start of auction can also be set to a later time by the item owner)
  // create item auction struct and create instance and store in a mapping for each item on auction
  // this will store item id (this can be used to trace back Market Item Attributes), highest bid, highest bidder, mapping of bids, ending time, started, ended 

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


    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false,
      payable(msg.sender),
      payable(address(0)),
      payable(address(0)),
      0
    ); 

    owners[itemId][0] = payable(msg.sender);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false,
      msg.sender,
      address(0),
      address(0),
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
      //maybe add require idToMarketItem[itemId].sold == false;
    idToMarketItem[itemId].saleCount=idToMarketItem[itemId].saleCount+1; //numberOftimes item is sold

    uint price = idToMarketItem[itemId].price;
    uint tokenId = idToMarketItem[itemId].tokenId;

    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    if(idToMarketItem[itemId].saleCount==1)
    {
    idToMarketItem[itemId].seller.transfer(msg.value);
    }
    if(idToMarketItem[itemId].saleCount==2)
    {
    owners[itemId][0].transfer((msg.value*royalties/100*royalty_a/100));//First owner commission= msg.value*a*r
    owners[itemId][idToMarketItem[itemId].saleCount-1].transfer(msg.value*royalties/100*(100-royalty_a)/100);//last seller royalty= msg.value*r*c
    owners[itemId][idToMarketItem[itemId].saleCount-1].transfer(msg.value*(100-royalties)/100);//last seller sale = 90% of sale price
    }
    if(idToMarketItem[itemId].saleCount>2){
      //r =0.10, a=0.50, b=0.30, c=0.20
      owners[itemId][0].transfer((msg.value*royalties/100*royalty_a/100));//First owner commission= msg.value*a*r
      for (uint i=1;i< idToMarketItem[itemId].saleCount-1; i++){ //for all indermediaries, commission =  (msg.value*r*b/i)
        owners[itemId][i].transfer((msg.value*royalties/100*royalty_b/100)/(idToMarketItem[itemId].saleCount-2));
      }
      owners[itemId][idToMarketItem[itemId].saleCount-1].transfer(msg.value*royalties/100*(100-royalty_a-royalty_b)/100);//last seller royalty= msg.value*r*c (c=100-a-b)
      owners[itemId][idToMarketItem[itemId].saleCount-1].transfer(msg.value*(100-royalties)/100); // last seller sale = 90% of sale price
      
      console.log("The first dude gets",msg.value*royalties/100*royalty_a/100);
      console.log("The last dude gets", (msg.value*royalties/100*(100-royalty_a-royalty_b)/100+msg.value*(100-royalties)/100));
      console.log("The middle men share is",(msg.value*royalties/100*royalty_b/100)/(idToMarketItem[itemId].saleCount-2));
      console.log("THE total amount the middle men get is",msg.value*royalties/100*royalty_b/100);
    }

   
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);  //Ownership transfer
    owners[itemId][idToMarketItem[itemId].saleCount]=payable(msg.sender); // the new owner is msg.sender
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();
    payable(owner).transfer(listingPrice);
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
    console.log("Token id", tokenId);
   
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
  }

  /*
    End auction function maybe can integrate the withdraw feature in this so users do not have to manually withdraw


  */


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