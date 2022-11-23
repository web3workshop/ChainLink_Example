// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract NFTV1 is ERC721Enumerable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Rinkeby coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;
    string public baseURI;
    uint256 public s_requestId;
    address owner;
    uint256 patch;
    mapping(uint256 => uint256) public requestIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToStartId;
    mapping(uint256 => uint256) public startIdToRandom;
    mapping(uint256 => uint256) public tokenIdToEther;
    uint256 lastStartId = 1;
    bool pause;
    uint256 startTime;
    uint256 endTime;

    constructor(
        uint64 subscriptionId,
        string memory name_,
        string memory symbol_
    ) VRFConsumerBaseV2(vrfCoordinator) ERC721(name_, symbol_) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function setBaseURI(string memory baseUri) external onlyOwner {
        baseURI = baseUri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function mint() public payable isNotPause {
        require(msg.value == 0.2 ether || msg.value == 2 ether || msg.value == 20 ether, "wrong ether amouts");
        require(tx.origin == msg.sender);
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "not in duration"
        );
        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);
        if(msg.value == 0.2 ether) {
          tokenIdToEther[tokenId] = 17;
        }
        if(msg.value == 2 ether) {
          tokenIdToEther[tokenId] = 18;
        }
        if(msg.value == 20 ether) {
          tokenIdToEther[tokenId] = 19;
        }
        tokenIdToStartId[tokenId] = lastStartId;
        if (tokenId >= lastStartId + patch) {
            requestRandomWords(tokenId);
        }
    }

    // function buy() public payable isNotPause {
    //   require(msg.value == 1 ether, "wrong ether amouts");
    //   require(
    //         block.timestamp >= startTime && block.timestamp <= endTime,
    //         "not in duration"
    //     );
    //     uint256 tokenId = totalSupply() + 1;
    //     _safeMint(msg.sender, tokenId);
    // }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint256 tokenId) internal {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToTokenId[s_requestId] = tokenId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        uint256 tokenId = requestIdToTokenId[requestId];
        startIdToRandom[lastStartId] = randomWords[0];
        lastStartId = tokenId + 1;
    }

    function getResult(uint256 tokenId) public view returns (uint256) {
        if (startIdToRandom[tokenIdToStartId[tokenId]] != 0) {
            return
                ((uint256(
                    keccak256(
                        abi.encodePacked(
                            startIdToRandom[tokenIdToStartId[tokenId]] + tokenId
                        )
                    )
                ) % 3) + 1) * 10**tokenIdToEther[tokenId];
        } else {
            return 0;
        }
    }

    function collection(uint256 _tokenId) external {
        require(block.timestamp > endTime, "withdraw after endTime");
        require(tx.origin == ownerOf(_tokenId), "not owner");
        uint256 reward = getResult(_tokenId);
        if (getBalance() < reward) {
            payable(tx.origin).transfer(getBalance());
        }
        payable(tx.origin).transfer(reward);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier isNotPause() {
        require(pause == false);
        _;
    }

    function setPause(bool isPause) external onlyOwner {
        pause = isPause;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}

    function setDuration(uint256 _startTime, uint256 _endTime)
        external
        onlyOwner
    {
        startTime = _startTime;
        endTime = _endTime;
    }

    function setPatch(uint256 _patch) external onlyOwner {
        require(_patch + lastStartId> totalSupply(), "patch too small");
        patch = _patch;
    }
}
