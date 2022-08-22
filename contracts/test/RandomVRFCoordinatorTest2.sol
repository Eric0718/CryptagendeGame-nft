// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract RandomNumberConsumer is VRFConsumerBase {
    
    bytes32 internal _keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
    uint256 internal _fee = 0.1 * 10 ** 18;
    uint256 public _randomResult;
    
    constructor() VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
        ){}
    

    function requestRandomness() public returns (bytes32 requestId) {
        return requestRandomness(_keyHash, _fee);
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        _randomResult = randomness;
    }
    
}