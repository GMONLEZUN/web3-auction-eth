// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Auction {

    address private owner;
    uint256 private topOffer;
    address private topOfferAccount;
    uint256 public startDateAuction;
    uint256 public  endDateAuction;
    bool private auctionClosed;
    uint256 public minimumNewOfferPercentage;
    uint256 public returnCommission;

    mapping (address account => uint256 amount) private offers;
    
    struct StructOfferAccount {
        address account;
        uint256 amount; 
    }
    
    StructOfferAccount[] offerRegistry;

    struct auxStructResult{
        address account;
        uint256 amount;
        bool auctionEnded;
    }

    constructor(uint256 _endDateAuction, uint256 _offer){
        auctionClosed = false;
        owner = msg.sender;
        topOffer = _offer;
        topOfferAccount = msg.sender;
        startDateAuction = block.timestamp;
        endDateAuction = startDateAuction + _endDateAuction;
        minimumNewOfferPercentage = 5;
        returnCommission = 2;
        offers[msg.sender] = _offer;
    }

    event newOfferEvent(address account, uint256 offer);

    event endAuctionEvent(address topAccount, uint256 topOffer, uint256 timestamp);

    modifier chkAuctionActive() {
        require(endDateAuction > block.timestamp, "You can't offer after the established period of the auction");
        require(!auctionClosed , "The auction is closed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can do this action.");
        _;
    }

    modifier goodBid() {
        uint256 minimumNewOffer = topOffer * (100 + minimumNewOfferPercentage) / 100; 
        uint256 newOffer = msg.value;
        require(newOffer > 0, "The amount offered for this auction must be higher than 0");
        if(topOffer != 0){
            require(newOffer > minimumNewOffer, "The amount offered for this auction must be 5% higher than the best offer"); 
        }
        _;
    }

    modifier checkLastTimeBid(){
        if(block.timestamp < endDateAuction - 10 seconds){
            endDateAuction += 10 seconds;
        }
        _;
    }

    function CreateOffer() external payable chkAuctionActive goodBid checkLastTimeBid {
        topOfferAccount = msg.sender;
        topOffer = msg.value;
        offers[msg.sender] = msg.value;

        StructOfferAccount memory auxInfo = StructOfferAccount({
            account: msg.sender,
            amount: msg.value
        });
        offerRegistry.push(auxInfo);
    }

    function ShowAuctionWinner() public view returns (auxStructResult memory){
        auxStructResult memory auxResult = auxStructResult({
            account: topOfferAccount,
            amount: topOffer,
            auctionEnded: auctionClosed

        });
        return auxResult;
    }

    function ShowAuctionOffers() public view returns (StructOfferAccount[] memory){
        return offerRegistry;
    }


    function EndAuction() external onlyOwner {
        require(block.timestamp > endDateAuction, "You can't end the auction before the stablished end date.");
        require(!auctionClosed, "The auction is already closed.");
        auctionClosed = true;
    }

    function refund(uint256 amount) public {
        require(offers[msg.sender] > 0,"Insufficient balance.");
        require(msg.sender != topOfferAccount, "You can't withdraw the winning bid");
        if(amount == 0){
            amount = offers[msg.sender];
        } else {
            require(amount <= offers[msg.sender], "Insufficient balance");
        }
        // Redondeo hacia arriba para retiros muy bajos; 49*2+99/100=1wei y para mantener la reutilización de código, 0wei retira todo lo que tiene la cuenta sender. 
        uint256 commission = (amount * returnCommission + 99) / 100;
        uint256 refundAmount = amount - commission;
        offers[msg.sender] -= amount;
        (bool refSent, ) = payable(msg.sender).call{value: refundAmount}("");
        require(refSent, "Failed to refund");
        // Envío comisión al owner
        (bool comSent, ) = payable(owner).call{value: commission}("");
        require(comSent, "Failed to send commission");
    }
}