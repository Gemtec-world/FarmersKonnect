// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma experimental ABIEncoderV2;
import "./Interfaces/LandStructLib.sol";

contract LandBookingSystem {

    address public owner;

    constructor(
        address _owner
    ) public {
        owner = _owner;
    }

    //storage variables for Issuers

    // issuerAddress -> Issuer
    mapping(address => LandStructLib.Issuer) public issuerMap;

    //storage variables for shows

    // mapping for: showId -> Show
    mapping(string => LandStructLib.Show) public showMap;

    //storage variables for land

    // landId -> LandBooking
    mapping(string => LandStructLib.LandBooking) public landBookingMap;

    // landId -> issuerAddress
    mapping(string => address) public landBookingIssuerMap;

    // landId -> customerAddress
    // landId is considered as Unique. i.e multiple shows wont share same landId
    mapping(string => address) public landBookingCustomerMap;

    modifier onlyOwner {
        require(msg.sender == owner, "only Owner can invoke the function");
        _;
    }

    function getOwner() public view returns(address){
        return owner;
    }

    modifier isIssuerAuthorised(address issuerAddress){
        require(issuerMap[msg.sender].issuerAddress == issuerAddress , "not Authorized to Invoke the function");
        _;
    }

    modifier isAnIssuerOfAShow(string memory _showId){
         require(showMap[_showId].issuer == msg.sender , "only Show Issuer can invoke the function");
        _;
    }

    function addALandIssuer(string memory _issuerId, address _issuerAddress, string memory _issuerName) onlyOwner public  {
        require(LandStructLib.isANonEmptyString(_issuerId), "invalid issuerId");
        require(!doesIssuerExist(_issuerAddress), "A LandIssuer is already created with this issuerId" );
        require(LandStructLib.isANonEmptyString(_issuerName), "invalid issuerName");
        LandStructLib.Issuer memory issuerObjectForPersistence;
        issuerObjectForPersistence = LandStructLib.Issuer({
                                                        issuerId : _issuerId,
                                                        issuerAddress: _issuerAddress,
                                                        issuerName : _issuerName,
                                                        createdAt : now,
                                                        updatedAt : 0});
        issuerMap[_issuerAddress] = issuerObjectForPersistence;
    }

    function getLandIssuerDetails(address _issuerAddress) public view returns(LandStructLib.Issuer memory issuer){
        require(doesIssuerExist(_issuerAddress), "LandIssuer doesnot exist with this issuerAddress");
        return issuerMap[_issuerAddress];
    }

    function doesIssuerExist(address _issuerAddress) public view returns(bool){
        require(LandStructLib.isAValidAddress(_issuerAddress), "issuerAddress is Invalid");
        return issuerMap[_issuerAddress].createdAt > 0;
    }

    function createAShow(
        string memory _showId,
        address _issuer,
        string memory _showName,
        uint256 _totalNumberOfLands,
        uint256 _showPrice,
        uint256 _showTime,
        string memory _showTimeAsGMT
        ) isIssuerAuthorised(_issuer) public {
        require(LandStructLib.isANonEmptyString(_showId), "invalid showId");
        require(doesIssuerExist(_issuer), "Issuer doesnot exist" );
        require(msg.sender == _issuer , "LandIssuer Can create Shows for the Self. Cannot create shows for other Issuers");
        require(!doesShowExist(_showId), "A Show is already created with this showId" );
        require(LandStructLib.isANonEmptyString(_showName), "invalid showName");
        require(LandStructLib.isAValidInteger(_totalNumberOfLands), "invalid totalNumberOfLands");
        require(LandStructLib.isAValidInteger(_showPrice), "invalid showPrice");
        require(LandStructLib.isAValidInteger(_showTime), "invalid showTime");
        require(LandStructLib.isANonEmptyString(_showTimeAsGMT), "invalid showTimeAsGMT");

        LandStructLib.Show memory showObjectForPersistence;
        showObjectForPersistence = LandStructLib.Show({
                                                        showId : _showId,
                                                        issuer: _issuer,
                                                        showName : _showName,
                                                        totalNumberOfLands: _totalNumberOfLands,
                                                        availableLandCount: _totalNumberOfLands,
                                                        showPrice : _showPrice,
                                                        showTime : _showTime,
                                                        showTimeAsGMT : _showTimeAsGMT,
                                                        createdAt : now,
                                                        updatedAt : 0});
        showMap[_showId] = showObjectForPersistence;
    }

    function getShowDetails(string memory _showId) public view returns(LandStructLib.Show memory show){
        require(doesShowExist(_showId), "show doesnot exist with this showId");
        return showMap[_showId];
    }

    function doesShowExist(string memory _showId) public view returns(bool){
        require(LandStructLib.isANonEmptyString(_showId), "showId is Invalid");
        return showMap[_showId].createdAt > 0;
    }

    modifier onlyLandCustomer(string memory _landId) {
        require(doesLandExist(_landId), "invalid landId");
        require(landBookingCustomerMap[_landId] == msg.sender, "message sender is not the land-holder");
        _;
    }

    //create a New LandBooking & Add mapping for LandBooking
    //Mark land as Locked
    function bookALand(
        string memory _landId,
        string memory _showId,
        address _issuer,
        address _customer,
        uint8 _lockPeriodInSeconds) isAnIssuerOfAShow(_showId) public {
        require(LandStructLib.isANonEmptyString(_landId), "invalid landId");
        require(LandStructLib.isANonEmptyString(_showId), "invalid showId");
        require(LandStructLib.isAValidAddress(_issuer), "invalid issuer Address");
        require(LandStructLib.isAValidAddress(_customer), "invalid customer Address");
        require(LandStructLib.isAValidInteger(_lockPeriodInSeconds), "invalid unlockDate value");
        require(_lockPeriodInSeconds > 0, "lockPeriodInSeconds should be a positive number");

        LandStructLib.Show storage showObjectFromStorage = showMap[_showId];
        require(showObjectFromStorage.availableLandCount>0, "Lands not Available for the Show");

        LandStructLib.LandBooking memory landBookingObjectForPersistence;

        landBookingObjectForPersistence = LandStructLib.LandBooking({
                                                        landId : _landId,
                                                        showId : _showId,
                                                        showPrice : showObjectFromStorage.showPrice,
                                                        showTime : showObjectFromStorage.showTime,
                                                        issuer: _issuer,
                                                        customer: _customer,
                                                        isLocked: 10,
                                                        lockedAt: now,
                                                        lockPeriodInSeconds: _lockPeriodInSeconds,
                                                        claimableFrom: now + _lockPeriodInSeconds * 1 seconds,
                                                        claimedAt: 0,
                                                        createdAt : now});

        landBookingMap[_landId] = landBookingObjectForPersistence;
        landBookingIssuerMap[_landId] = _issuer;
        landBookingCustomerMap[_landId] = _customer;
        showObjectFromStorage.availableLandCount = showObjectFromStorage.availableLandCount-1;
    }

    function getLandBookingDetails(string memory _landId) public view returns(LandStructLib.LandBooking memory landBooking){
        require(doesLandExist(_landId), "LandBooking doesnot exist with this landId");
        return landBookingMap[_landId];
    }

    function claimALand(string memory _landId) onlyLandCustomer(_landId) public {
        require(LandStructLib.isANonEmptyString(_landId), "invalid landId");
        _claimLand(_landId);
    }

    function _claimLand(string memory _landId) internal {
        LandStructLib.LandBooking storage landBookingObject = landBookingMap[_landId];
        require(landBookingObject.claimedAt == 0 , "Land is already Claimed");
        require(now >= landBookingObject.claimableFrom);
        landBookingObject.isLocked = 0;
        landBookingObject.claimedAt = now;
    }

    function doesLandExist(string memory _landId) public view returns(bool){
        require(LandStructLib.isANonEmptyString(_landId), "invalid landId");
        return landBookingMap[_landId].createdAt > 0;
    }

    function isTickedLockedForCustomer(string memory _landId, address _customer) public returns (bool) {
        require(doesLandExist(_landId), "invalid landId");
        require(LandStructLib.isAValidAddress(_customer), "invalid customer Address");
        return landBookingCustomerMap[_landId] == _customer;
    }

    function isLandClaimed(string memory _landId) public returns(bool){
        require(doesLandExist(_landId), "land doesnot exist");
        return landBookingMap[_landId].claimedAt > 0;
    }

    function isLandLocked(string memory _landId) public returns(bool){
        require(doesLandExist(_landId), "land doesnot exist");
        return landBookingMap[_landId].isLocked > 0;
    }
}