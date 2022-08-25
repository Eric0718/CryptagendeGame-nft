// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract CryptagendeGame is ERC721Enumerable, VRFConsumerBaseV2, Ownable {
    using Strings for uint256;
    using Strings for uint8;

    // Chainlink VRF Variables
    //network coordinator
    VRFCoordinatorV2Interface private immutable _vrfCoordinator;

    //The gas lane to use, which specifies the maximum gas price to bump to.
    bytes32 private immutable _gasLane;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Adjust this limit based on the network 
    // that you select, the size of the request,and the processing of the 
    // callback request in the fulfillRandomWords() function.
    uint32 private CALLBACKGASLIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // retrieve NUM_WORDS random values in one request.
    uint32 private  constant NUM_WORDS = 1;


    // NFT Variables
    //base URI;
    string private _tokenBaseURI = "https://cryptagende.mypinata.cloud/ipfs/QmcbyaahDpJkNPzsYuWWn7iMJNBzmdZ9igd7LWJD5jYFRH";

    //totalsupply
    uint256 public constant maxSupply = 10001;

    // string private _name = "Cryptagende 01 season: Battle of the gods";
    // string private _symbol = "CBOG";

    bool private _paused = false;

    //keep the randomWords from fulfillRandomWords() function.
    uint256 private _randomWords;

    //0.065ETH
    uint256 private _whiteMintFee = 65000000000000000;

    //0.081ETH
    uint256 private _ordinaryMintFee = 81000000000000000;
    //white list
    mapping(address => bool) _whiteList;

    //mint amount limit each time.
    uint32 private _mintLimitEach = 50;

    //Number of images in each level
    uint256[8] private imagesEachLevel = [0, 20, 400, 600, 1500, 3200, 3700, 5300];

    //level range
    uint8[8] private levelIDs = [0, 1, 2, 3, 4, 5, 6, 7];

    //lv1:3%,lv2：5%,lv3:8%,lv4:12%,lv5:18%,lv6:24%,lv7:30%
    uint256[8] private percentageLevel = [0, 30, 80, 160, 280, 460, 700, 1000];

    // Events
    event RequestedRandomWords(uint256 requestId ,address requester);
  
    constructor(
        string memory _name,
        string memory _symbol,
        address vrfCoordinatorV2,
        bytes32 gasLane
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721(_name, _symbol) {
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        _gasLane = gasLane;
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override{
       _randomWords = randomWords[0];
        CALLBACKGASLIMIT = 0;
    }

    function requestRandomWords(uint64 subscriptionId)external onlyOwner{
        require(_randomWords == 0,"RandomWods already requested!");
        require(CALLBACKGASLIMIT > 0,"CALLBACKGASLIMIT is 0!");
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACKGASLIMIT,
            NUM_WORDS
        );
        emit RequestedRandomWords(requestId, msg.sender);
    }

    function mint(uint256 mintNum)public payable{
        uint256 supply = totalSupply();
        require(mintNum <= _mintLimitEach,"Mint limit is 50 each time!");
        require(_randomWords > 0,"Mint: request a random nmber first!");
        require(supply + mintNum <= maxSupply,"Mint is over!");
        require(!_paused,"Mint is puased!");
        require(msg.sender != address(0), "Invalid user address!");
        
        if (_whiteList[msg.sender]){
            if (msg.value < mintNum * _whiteMintFee){
                revert("WhiteList mint fee not enough!");
            }
        }else{
            if (msg.value < mintNum * _ordinaryMintFee){
                revert("Ordinary mint fee not enough!");
            }
        }

        for (uint256 i = 1;i <= mintNum;i++){ 
            _safeMint(msg.sender, supply + i);
        }
    }

    function _generateTokenURIByRandomNumber(uint256 tokenId) private view returns (string memory) {
        if (_randomWords == 0){
            revert("Request a random nmber first!");
        }
        uint256 randomNumber = uint256(keccak256(abi.encode(_randomWords, tokenId)));
        
        uint8 levelId;
        uint256 rand = randomNumber % percentageLevel[percentageLevel.length -1] + 1;

        for(uint8 i = 1;i < percentageLevel.length;i++){
            if (rand > percentageLevel[i-1] && rand <= percentageLevel[i]){
                levelId = levelIDs[i];
                break;
            }
        }
      
        uint256 imageId = randomNumber % imagesEachLevel[levelId] + 1;
     
        return string(abi.encodePacked(_tokenBaseURI, "/", levelIDs[levelId].toString(), "/", imageId.toString(), ".json"));
    }

    function withdraw() public payable onlyOwner {
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

    function tokenURI(uint256 tokenId) public view override returns(string memory){
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexisting token");
        return _generateTokenURIByRandomNumber(tokenId);
    }

    function setPause()public onlyOwner{
        _paused = !_paused;
    }

    function addWhiteList(address _addr)public onlyOwner{
        _whiteList[_addr] = true;
    }

    function removeWhiteList(address _addr)public onlyOwner{
        _whiteList[_addr] = false;
    }

    function userInWhiteList(address _addr)public view returns(bool){
        return _whiteList[_addr];
    }

    function getMintLimitEach()public view returns(uint32){
        return _mintLimitEach;
    }

    function setMintLimitEach(uint32 maxAmnout)public onlyOwner{
        _mintLimitEach = maxAmnout;
    }

    function baseURI() public view returns (string memory) {
        return _tokenBaseURI;
    }

    function setBaseURI(string memory baseUri) public onlyOwner{
        _tokenBaseURI = baseUri;
    }
}