// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "hardhat/console.sol";


error NeedMoreETHSent();
error RangeOutOfBounds();
error MintIsOver();
error  OutOfLevelRange();

contract CryptagendeGame is ERC721URIStorage, VRFConsumerBaseV2, Ownable {
    using Strings for uint256;
    using Strings for uint8;

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable _vrfCoordinator;
    uint64 private immutable _subscriptionId;
    bytes32 private immutable _gasLane;
    uint32 private immutable _callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // NFT Variables
    uint256 private _mintFee = 1000000000000000;
    uint256 public _tokenCounter = 0;

    string private _baseTokenURI = "https://cryptagende.mypinata.cloud/ipfs/QmcbyaahDpJkNPzsYuWWn7iMJNBzmdZ9igd7LWJD5jYFRH";
    uint256 private _totalSupply = 10001;
    string private _name = "Cryptagende 01 season: Battle of the gods";
    string private _symbol = "BOG";
  
    uint256[8] private imageIDRange = [0, 20, 400, 600, 1500, 3200, 3700, 5300];
    uint8[8] private levelIDs = [0, 1, 2, 3, 4, 5, 6, 7];
    uint256[8] private percentRange = [0, 1, 36, 90, 240, 440, 650, 1000];

    mapping(uint256 => bool) opened;
    mapping(uint256 => string) tokenURIs;

    // VRF Helpers
    mapping(uint256 => address) public _requestIdToSender;

    // Events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(address minter,uint256 tokenID);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721(_name, _symbol) {
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        _gasLane = gasLane;
        _subscriptionId = subscriptionId;
        _callbackGasLimit = callbackGasLimit;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{}

    function requestRandomWords() private returns (uint256 requestId) {
        requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            _subscriptionId,
            REQUEST_CONFIRMATIONS,
            _callbackGasLimit,
            NUM_WORDS
        );

        _requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    function mint()public payable {
        if (_tokenCounter+1 > _totalSupply){
            revert MintIsOver(); 
        }
        if (msg.value < _mintFee) {
            revert NeedMoreETHSent();
        }
        uint256 requestId = requestRandomWords();
        string memory tokenUri = getCardURI(requestId);
        
        address cryptaOwner = _requestIdToSender[requestId];
        uint256 tokenId = _tokenCounter;
        _tokenCounter = _tokenCounter + 1;

        _safeMint(cryptaOwner, tokenId);
        _setTokenURI(tokenId, tokenUri);
        emit NftMinted(cryptaOwner,tokenId);
    }

    function getCardURI(uint256 requestId) private returns (string memory) {
        uint8 levelid;
        uint256 rand = requestId % percentRange[percentRange.length -1];
        if(rand == 0){
            revert OutOfLevelRange();
        }

        for(uint8 i = 1;i < percentRange.length;i++){
            if (rand > percentRange[i-1] && rand <= percentRange[i]){
                levelid = levelIDs[i];
            }
        }

        uint256 imageid = rand % (imageIDRange[levelid] - imageIDRange[levelid-1]);
        if(imageid == 0){
            revert OutOfLevelRange();
        }

        return string(abi.encodePacked(_baseTokenURI, "/", levelIDs[levelid].toString(), "/", imageIDRange[imageid].toString(), ".json"));
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setMintFee(uint256 mintFee)public onlyOwner{
        _mintFee = mintFee;
    }

    function getMintFee() public view returns (uint256) {
        return _mintFee;
    }

    function tokenCounter() public view returns (uint256) {
        return _tokenCounter;
    }
    function totalSupply()public view returns(uint256){
        return _totalSupply;
    }
}