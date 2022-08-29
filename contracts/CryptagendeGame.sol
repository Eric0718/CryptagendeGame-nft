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
    uint32 private immutable CALLBACKGASLIMIT;

    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // retrieve NUM_WORDS random values in one request.
    uint32 private  constant NUM_WORDS = 1;


    // NFT Variables
    //base URI;
    string private _tokenBaseURI;
    //totalsupply
    uint256 public constant maxSupply = 10001;

    // string private _name = "Cryptagende 01 season: Battle of the gods";
    // string private _symbol = "CBOG";

    bool private _paused = false;

    //keep the randomWords from fulfillRandomWords() function.
    uint256 private _randomWords = 0;

    //0.064ETH
    uint256 private immutable _whiteMintFee;

    //0.08ETH
    uint256 private immutable _ordinaryMintFee;
    //white list
    mapping(address => bool) _whiteList;

    //mint amount limit each time.
    uint32 private _mintLimitEach;

    //Number of images in each level
    uint256[8] private imagesEachLevel = [0, 20, 400, 600, 1500, 3200, 3700, 5300];

    //level range
    uint8[8] private levelIDs = [0, 1, 2, 3, 4, 5, 6, 7];

    //percentageLevel=> lv1:3%,lv2：5%,lv3:8%,lv4:12%,lv5:18%,lv6:24%,lv7:30%
    uint256[8] private percentageLevel = [0, 30, 80, 160, 280, 460, 700, 1000];

    //URI suffix
    string _uriSuffix = ".json";

    // Events
    event RequestedRandomWords(uint256 requestId ,address requester);
  
    constructor(
        string memory _name,
        string memory _symbol,
        address vrfCoordinatorV2,
        bytes32 gasLane
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721(_name, _symbol) {
        _mintLimitEach = 50;
        _whiteMintFee = 64000000000000000;
        _ordinaryMintFee = 80000000000000000;
        _gasLane = gasLane;
        CALLBACKGASLIMIT = 100000;
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        _tokenBaseURI = "https://cryptagende.mypinata.cloud/ipfs/QmcbyaahDpJkNPzsYuWWn7iMJNBzmdZ9igd7LWJD5jYFRH";
    }

    /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param randomWords the VRF output expanded to the requested number of words
   */
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override{
        require(_randomWords == 0);
       _randomWords = randomWords[0];
    }

    // request a random number from VRFCoordinator V2
    function requestRandomWords(uint64 subscriptionId)external onlyOwner{
        require(_randomWords == 0,"RandomWods already requested!");
        require(CALLBACKGASLIMIT > 0,"You don't need to requestRandomWords!");
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACKGASLIMIT,
            NUM_WORDS
        );
        emit RequestedRandomWords(requestId, msg.sender);
    }

    // mint nfts with a mintNum 
    function mint(uint256 mintNum)public payable{
        uint256 supply = totalSupply();
        require(_randomWords > 0,"Mint: request a random nmber first!");
        require(mintNum <= _mintLimitEach,"Mint limit is 50 each time!");
        require(supply < maxSupply,"All cards have been Claimed.");
        require(supply + mintNum <= maxSupply,"Mint amount is over left!");
        require(!_paused,"Mint is puased!");
        require(msg.sender != address(0), "Invalid user address!");
        
        if (_whiteList[msg.sender]){
            if (msg.value < SafeMath.mul(mintNum, _whiteMintFee)){//mintNum * _whiteMintFee){
                revert("WhiteList mint fee not enough!");
            }
        }else{
            if (msg.value < SafeMath.mul(mintNum, _ordinaryMintFee)){
                revert("Ordinary mint fee not enough!");
            }
        }

        for (uint256 i = 1;i <= mintNum;i++){ 
            _safeMint(msg.sender, supply + i);
        }
    }

    //generate TokenURI By RandomNumber and tokenId
    function _generateTokenURIByRandomNumber(uint256 tokenId) private view returns (string memory) {
        require (_randomWords > 0,"Request a random number first!");
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexisting token");
        
        uint8 levelId;
        uint256 randomNumber = uint256(keccak256(abi.encode(_randomWords, tokenId)));
        uint256 rand = SafeMath.mod(randomNumber, percentageLevel[percentageLevel.length -1]) + 1; 
        require(rand >= 1 && rand <= percentageLevel[percentageLevel.length -1],"Rand out of percentageLevel!");

        for(uint8 i = 1;i < percentageLevel.length;i++){
            if (rand > percentageLevel[i-1] && rand <= percentageLevel[i]){
                levelId = levelIDs[i];
                break;
            }
        }
      
        uint256 imageId = SafeMath.mod(randomNumber,imagesEachLevel[levelId]) + 1;
        require(imageId >= 1 && rand <= imagesEachLevel[levelId],"ImageId out of imagesEachLevel!");

        string memory baseUri = _baseURI();
        require(bytes(baseUri).length > 0,"TokenBaseURI is empty,please set it first!");

        return string(abi.encodePacked(baseUri, "/", levelIDs[levelId].toString(), "/", imageId.toString(), _uriSuffix));
    }

    // withdraw balance in contract
    function withdraw() public payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // get whiteList mint fee
    function getwhiteMintFee() public view returns (uint256) {
        return _whiteMintFee;
    }

    // get ordinary user mint fee 
    function getOrdinaryMintFee() public view returns (uint256) {
        return _ordinaryMintFee;
    }

    //get tokenURI by tokenId
    function tokenURI(uint256 tokenId) public view override returns(string memory){
        return _generateTokenURIByRandomNumber(tokenId);
    }

    //set pause or unpause.
    function setPause()public onlyOwner{
        _paused = !_paused;
    }

    // add user into whiteList
    function addWhiteList(address[] calldata _addrs)public onlyOwner{
        for(uint256 i = 0;i < _addrs.length;i++){
            _whiteList[_addrs[i]] = true;
        }
    }

    //remove user from whiteList
    function removeWhiteList(address _addr)public onlyOwner{
        _whiteList[_addr] = false;
    }

    // Is user in whiteList
    function userInWhiteList(address _addr)public view returns(bool){
        return _whiteList[_addr];
    }

    //get each mint limit
    function getMintLimitEach()public view returns(uint32){
        return _mintLimitEach;
    }

    //set mint limit 
    function setMintLimitEach(uint32 maxAmnout)public onlyOwner{
        _mintLimitEach = maxAmnout;
    }

    // get baseURI
    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    //set baseURI
    function setBaseURI(string memory baseUri) public onlyOwner{
        _tokenBaseURI = baseUri;
    }

    // override _baseURI
    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }
}

library SafeMath {
    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}