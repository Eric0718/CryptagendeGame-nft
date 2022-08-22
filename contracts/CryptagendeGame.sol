// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
//import "hardhat/console.sol";

contract CryptagendeGame is ERC721Enumerable, VRFConsumerBaseV2, Ownable {
    using Strings for uint256;
    using Strings for uint8;

    // Chainlink VRF Variables
    //network coordinator
    VRFCoordinatorV2Interface private immutable _vrfCoordinator;

    //subscription ID
    uint64 private immutable _subscriptionId;

    //The gas lane to use, which specifies the maximum gas price to bump to.
    bytes32 private immutable _gasLane;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Adjust this limit based on the network 
    // that you select, the size of the request,and the processing of the 
    // callback request in the fulfillRandomWords() function.
    uint32 private _vrfCallbackGasLimit = 2500000;

    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 10;

    // retrieve NUM_WORDS random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    //uint32 private constant NUM_WORDS = 100;
    uint32 private  NUM_WORDS = 100;


    // NFT Variables
    //token counter,Continue to increase
    uint256 private _tokenCounter = 0;

    //base URI;
    string private _tokenBaseURI = "https://cryptagende.mypinata.cloud/ipfs/QmcbyaahDpJkNPzsYuWWn7iMJNBzmdZ9igd7LWJD5jYFRH";

    //totalsupply
    uint256 private _totalSupply = 10001;

    // string private _name = "Cryptagende 01 season: Battle of the gods";
    // string private _symbol = "CBOG";

    bool private _paused = false;

    //keep the randomWords from fulfillRandomWords() function.
    uint256[] private _randomWords = new uint256[](0);

    //0.065ETH
    uint256 private _whiteMintFee = 65000000000000000;

    //0.081ETH
    uint256 private _ordinaryMintFee = 81000000000000000;
    //white list
    mapping(address => bool) _whiteList;

    //Number of images in each level
    uint256[8] private imageIDRange = [0, 20, 400, 600, 1500, 3200, 3700, 5300];

    //level range
    uint8[8] private levelIDs = [0, 1, 2, 3, 4, 5, 6, 7];

    //lv1:3%,lv2：5%,lv3:8%,lv4:12%,lv5:18%,lv6:24%,lv7:30%
    uint256[8] private percentRange = [0, 30, 80, 160, 280, 460, 700, 1000];

    // Events
    event RequestedRandomWords(uint256 indexed _tokenCounter,uint256 requestId ,address requester);
  
    constructor(
        string memory _name,
        string memory _symbol,
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane 
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721(_name, _symbol) {
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        _gasLane = gasLane;
        _subscriptionId = subscriptionId;
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override{
        for(uint256 i = 0;i < randomWords.length;i++){
            _randomWords.push(randomWords[i]);
        }
    }

    function requestRandomWords()external onlyOwner{
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            _subscriptionId,
            REQUEST_CONFIRMATIONS,
            _vrfCallbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRandomWords(_tokenCounter ,requestId, msg.sender);
    }

    function mint(uint256 mintNum)public payable{
        require(_tokenCounter + mintNum <= _totalSupply,"Mint is over!");
        require(!_paused,"Mint is puased!");
        require(msg.sender != address(0), "Invalid user address!");
        require(mintNum + _tokenCounter <= _randomWords.length,"Not enough randomWords to use!");

        if (_whiteList[msg.sender]){
            if (msg.value < mintNum * _whiteMintFee){
                revert("Mint fee not enough!");
            }
        }else{
            if (msg.value < mintNum * _ordinaryMintFee){
                revert("Mint fee not enough!");
            }
        }

        address cryptaOwner = msg.sender;
        for (uint256 i = 0;i < mintNum;i++){ 
            uint256 tokenId = _tokenCounter;
            _tokenCounter = _tokenCounter + 1;
            _safeMint(cryptaOwner, tokenId);
        }
    }

    function _generateTokenURIByRandomNumber(uint256 tokenId) private view returns (string memory) {
        uint256 randomNumber = _randomWords[tokenId];
        if ( randomNumber == 0){
                revert("mint failed! Need to request a random number first!");
        }
        
        uint8 levelId;
        uint256 rand = randomNumber % percentRange[percentRange.length -1];

        for(uint8 i = 1;i < percentRange.length;i++){
            if (rand > percentRange[i-1] && rand <= percentRange[i]){
                levelId = levelIDs[i];
                break;
            }
        }
        if (levelId ==0){
            revert("Invalid levelId");
        }
        uint256 imageId = randomNumber % imageIDRange[levelId];
        if (imageId == 0){
            revert("Invalid imageId");
        }
        return string(abi.encodePacked(_tokenBaseURI, "/", levelIDs[levelId].toString(), "/", imageId.toString(), ".json"));
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setWhiteMintFee(uint256 mintFee)public onlyOwner{
        _whiteMintFee = mintFee;
    }

    function getwhiteMintFee() public view returns (uint256) {
        return _whiteMintFee;
    }

    function setOrdinaryMintFee(uint256 mintFee)public onlyOwner{
        _ordinaryMintFee = mintFee;
    }

    function getOrdinaryMintFee() public view returns (uint256) {
        return _ordinaryMintFee;
    }

    function tokenCounter() public view returns (uint256) {
        return _tokenCounter;
    }

    function totalSupply()public view override returns(uint256){
        return _totalSupply;
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory){
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexisting token");
        return _generateTokenURIByRandomNumber(tokenId);
    }

    function getRandomWords(uint256 index)public view returns(uint256){
        return _randomWords[index];
    }

    function setPause(bool _state)public onlyOwner{
        _paused = _state;
    }

    function addWhiteList(address _addr)public onlyOwner{
        _whiteList[_addr] = true;
    }

    function removeWhiteList(address _addr)public onlyOwner{
        _whiteList[_addr] = false;
    }

    function setVrfCallbackGasLimit(uint32 _limit) public onlyOwner{
        _vrfCallbackGasLimit = _limit;
    }

    function userInWhiteList(address _addr)public view returns(bool){
        return _whiteList[_addr];
    }
}