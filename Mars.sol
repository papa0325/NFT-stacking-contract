// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MarsHouse is ERC721("Mars House", "Mars"), IERC721Receiver, ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    string private baseURI1 = "ipfs://QmTQ3U5enGBnJv7xNA8vP2BhsbdNazMYrUCm5URBCV6PNT/";     // Super rare
    string private baseURI2 = "ipfs://QmQUjvfSR9ZePeJowpmyMdzNX6jXGCDMSPPjFLHLM9RJYV/";     // Very rare
    string private baseURI3 = "ipfs://QmPxtTTH89LauCGy7PAmsx537PqVN761qycq1cMnDPUKDL/";     // rare
    string private baseURI4 = "ipfs://QmeyrEjqQAotCn3JfkH6oU5RAuSQJxJ1o3TTbhvZPstAXC/";     // normal

    address private adminAddress = address(0xbE99aa2f48324E04f4Bb657b5C4C85dc726Be451);
    // address private coinAddress = address(0x461FD80F6763723e04BdCf7D0E905160A8CAebfa);
    address private coinAddress = address(0x72845e08cfe989D987DaC1320a72228DEC1F0CAd);
    uint256 private bnb_price = 2500000000000000;      //0.0025 BNB
    uint256 private lhc_price = 120 * 10 ** 8;
    uint256 public MAX_NFT = 5000;
    uint256 public MAX_SUPER_RARE = 500;
    uint256 public MAX_VERY_RARE = 1000;
    uint256 public MAX_RARE = 1500;
    uint256 public MAX_NORMAL = 2000;
    uint256 public MAX_MINT_COUNT = 10;
    uint256 public super_rare_reward = 15 * 10 ** 7;
    uint256 public very_rare_reward = 125 * 10 ** 6;
    uint256 public rare_reward = 1 * 10 ** 8;
    uint256 public normal_reward = 4 * 10 ** 7;

    struct stakeTokenInfo {
        uint256 tokenId;
        uint256 rarity;
        uint256 claimedBalance;
        uint256 lastClaimedTime;
        uint256 createdTime;
        address owner;
    }

    mapping(uint256 => uint256) private tokenInfo;      //tokenId -> rarity

    mapping(uint256 => uint256) private rarityInfo;     //rarity -> count of token

    mapping(address => stakeTokenInfo[]) public stakeTokens;        //address -> stakeTokenInfo

    mapping(uint256 => uint256) public isStaked;

    mapping(address => uint256) public userRewardBalance;

    event staked(address owner, uint256 tokenId);
    event unstaked(address owner, uint256 tokenId);
    event claimed(address owner, uint256 amount, uint256 fee);

    constructor() {}

    function withdraw(address _to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(_to).transfer(balance);
    }

    function setLightCoin(address _addr) external onlyOwner {
        coinAddress = _addr;
    }

    function setAdmin(address _addr) external onlyOwner {
        adminAddress = _addr;
    }

    function mintNFT(uint256 _numOfTokens, uint256 _mintType) public payable {
        require(totalSupply().add(_numOfTokens) <= MAX_NFT, "Purchase would exceed max supply of NFTs");
        if(_mintType == 1) {
            require(bnb_price.mul(_numOfTokens) == msg.value, "BNB value sent is not correct");
        }
        require(_numOfTokens <= MAX_MINT_COUNT, "Mint count exceed");

        if(_mintType == 2) {       // mint with LHC
            ERC20(coinAddress).transferFrom(msg.sender, adminAddress, lhc_price.mul(_numOfTokens));
        }
        for (uint256 i = 1; i <= _numOfTokens; i++) {
            uint256 rarity = random(totalSupply() + 1);
            tokenInfo[totalSupply() + 1] = rarity;
            rarityInfo[rarity] += 1;
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function getRarityTokenCount(uint256 _rarity) public view returns (uint256) {
        return rarityInfo[_rarity];
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI;
        uint256 rarity = tokenInfo[tokenId];
        if(rarity == 1) {
            currentBaseURI = baseURI1;
        } else if (rarity == 2) {
            currentBaseURI = baseURI2;
        } else if (rarity == 3) {
            currentBaseURI = baseURI3;
        } else {
            currentBaseURI = baseURI4;
        }
        return bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(currentBaseURI, tokenId.toString(), ".json")
                )
                : "";
    }

    function setTokenBNBPrice(uint256 _price) public onlyOwner {
        bnb_price = _price;
    }

    function getTokenBNBPrice() public view returns (uint256) {
        return bnb_price;
    }

    function setTokenLHCPrice(uint256 _price) public onlyOwner {
        lhc_price = _price;
    }

    function getTokenLHCPrice() public view returns (uint256) {
        return lhc_price;
    }

    function setBaseURI(string memory _pBaseURI, uint256 _rarity) public onlyOwner {
        if(_rarity == 1) {
            baseURI1 = _pBaseURI;
        } else if (_rarity == 2) {
            baseURI2 = _pBaseURI;
        } else if (_rarity == 3) {
            baseURI3 = _pBaseURI;
        } else {
            baseURI4 = _pBaseURI;
        }
    }

    function _baseURI(uint256 _rarity) internal view virtual returns (string memory) {
        string memory retStr;
        if(_rarity == 1) {
            retStr = baseURI1;
        } else if (_rarity == 2) {
            retStr = baseURI2;
        } else if (_rarity == 3) {
            retStr = baseURI3;
        } else {
            retStr = baseURI4;
        }
        return retStr;
    }

    function getBaseURIs() public view returns (string[] memory) {
        string[] memory uris = new string[](4);
        uris[0] = baseURI1;
        uris[1] = baseURI2;
        uris[2] = baseURI3;
        uris[3] = baseURI4;
        return uris;
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // Standard functions to be overridden
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }

    function random(uint256 _tokenId) public view returns (uint256) {
        uint256 rarity = uint256(keccak256(abi.encodePacked(block.timestamp, _tokenId))).mod(4) + 1;
        if(rarity == 1 && rarityInfo[rarity] >= MAX_SUPER_RARE) {
            random(_tokenId);
        } else if(rarity == 2 && rarityInfo[rarity] >= MAX_VERY_RARE) {
            random(_tokenId);
        } else if(rarity == 3 && rarityInfo[rarity] >= MAX_RARE) {
            random(_tokenId);
        } else if(rarity == 4 && rarityInfo[rarity] >= MAX_NORMAL) {
            random(_tokenId);
        } else {
            return rarity;
        }
        return rarity;
    }

    function getTokenRarity(uint256 _tokenId) public view returns(uint256) {
        return tokenInfo[_tokenId];
    }

    function getOwnerTokens(address _owner) public view returns (string memory) {
        string memory json;

        json = "[";
        uint256 token_id = 0;
        for (uint256 i = 0; i < ERC721.balanceOf(_owner); i++) {
            token_id = ERC721Enumerable.tokenOfOwnerByIndex(_owner, i);
            json = string(abi.encodePacked(json,
                "{\"tokenId\":\"", string(abi.encodePacked(
                    token_id.toString(), ",",
                    tokenInfo[token_id].toString(), ",",
                    isStaked[token_id].toString())),
                "\"}"));
            if (i < ERC721.balanceOf(_owner) - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]"));
        return json;
    }

    function getStakeTokens(address _owner) public view returns (string memory) {
        string memory json = "[";
        for(uint256 i = 0; i < stakeTokens[_owner].length; i++) {
            json = string(abi.encodePacked(json,
                "{\"tokenId\":\"", string(abi.encodePacked(
                    stakeTokens[_owner][i].tokenId.toString(), ",",
                    stakeTokens[_owner][i].rarity.toString(), ",",
                    isStaked[stakeTokens[_owner][i].tokenId].toString())),
                "\",\"createdTime\":\"", string(abi.encodePacked(
                    stakeTokens[_owner][i].claimedBalance.toString(), ",",
                    stakeTokens[_owner][i].createdTime.toString(), ",",
                    stakeTokens[_owner][i].lastClaimedTime.toString())),
                "\"}"));
            if(i < stakeTokens[_owner].length - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]"));
        return json;
    }

    function stakeToken(uint256 _tokenId) public returns (uint256) {
        require(isStaked[_tokenId] != 1, "Already staked");
        require(ERC721.ownerOf(_tokenId) == msg.sender, "Token owner does not match");

        isStaked[_tokenId] = 1;
        stakeTokens[msg.sender].push(stakeTokenInfo(_tokenId, tokenInfo[_tokenId], 0, block.timestamp, block.timestamp, ERC721.ownerOf(_tokenId)));
        safeTransferFrom(msg.sender, address(this), _tokenId);
        emit staked(msg.sender, _tokenId);

        return block.timestamp;
    }

    function checkUnstake(uint256 tokenId) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](2);
        result = _check(tokenId, block.timestamp, msg.sender);
        uint256[] memory retVal = new uint256[](3);
        retVal[0] = block.timestamp;
        retVal[1] = result[0];
        retVal[2] = result[1];
        return retVal;
    }

    function _check(uint256 _tokenId, uint256 _timestamp, address _owner) private view returns (uint256[] memory) {
        require(isStaked[_tokenId] == 1, "Token has not been staked");
        stakeTokenInfo[] memory stakeData = stakeTokens[_owner];
        uint256 _index = 0;
        for(uint256 i = 0; i < stakeData.length; i++) {
            if(stakeData[i].tokenId == _tokenId) {
                _index = i + 1;
            }
        }
        require(_index > 0, "Not found the token");
        require(stakeTokens[_owner][_index - 1].owner == _owner, "Token owner does not match");

        uint256 stakedTime = _timestamp - stakeTokens[_owner][_index - 1].createdTime;
        uint256 claimedTime = _timestamp - stakeTokens[_owner][_index - 1].lastClaimedTime;
        uint256 claimedBalance = stakeTokens[_owner][_index - 1].claimedBalance;
        uint256 _rarity = tokenInfo[stakeData[_index - 1].tokenId];

        uint256 unstakeFee = 0;
        uint256 rewardToken = 0;
        if(_rarity == 1) {
            rewardToken = claimedTime.mul(super_rare_reward.div(86400));
            if(stakedTime <= 2 minutes ) {
                unstakeFee = (claimedBalance + rewardToken) * 30 / 100;
            } else if (stakedTime <= 3 minutes) {
                unstakeFee = (claimedBalance + rewardToken) * 10 / 100;
            }
        } else if(_rarity == 2) {
            rewardToken = claimedTime.mul(very_rare_reward.div(86400));
            if(stakedTime <= 2 minutes ) {
                unstakeFee = (claimedBalance + rewardToken) * 30 / 100;
            } else if (stakedTime <= 3 minutes) {
                unstakeFee = (claimedBalance + rewardToken) * 10 / 100;
            }
        } else if(_rarity == 3) {
            rewardToken = claimedTime.mul(rare_reward.div(86400));
            if(stakedTime <= 2 minutes ) {
                unstakeFee = (claimedBalance + rewardToken) * 30 / 100;
            } else if (stakedTime <= 3 minutes) {
                unstakeFee = (claimedBalance + rewardToken) * 10 / 100;
            }
        } else {
            rewardToken = claimedTime.mul(normal_reward.div(86400));
            if(stakedTime <= 2 minutes ) {
                unstakeFee = (claimedBalance + rewardToken) * 30 / 100;
            } else if (stakedTime <= 3 minutes) {
                unstakeFee = (claimedBalance + rewardToken) * 10 / 100;
            }
        }

        uint256[] memory ret = new uint256[](2);
        ret[0] = rewardToken;
        ret[1] = unstakeFee;
        return ret;
    }

    function unstakeToken(uint256 _tokenId, uint256 _fee, uint256 _rewards) public {

        stakeTokenInfo[] memory stakeData = stakeTokens[msg.sender];
        uint256 _index = 0;
        for(uint256 i = 0; i < stakeData.length; i++) {
            if(stakeData[i].tokenId == _tokenId) {
                _index = i + 1;
            }
        }

        ERC20(coinAddress).transferFrom(adminAddress, msg.sender, _rewards);

        if(_fee > 0) {
            ERC20(coinAddress).transferFrom(msg.sender, address(this), _fee);
            ERC20(coinAddress).transfer(adminAddress, _fee);
        }
        userRewardBalance[msg.sender] += (_rewards - _fee);
        isStaked[_tokenId] = 2;

        delete stakeTokens[msg.sender];
        for(uint256 j = 0; j < stakeData.length; j++) {
            if(j != _index - 1) {
                stakeTokens[msg.sender].push(stakeData[j]);
            }
        }

        _transfer(address(this), msg.sender, _tokenId);
        emit unstaked(msg.sender, _tokenId);
    }

    function claim() public returns (uint256[] memory) {

        uint256 superRareRewardPerSecond = super_rare_reward.div(86400);
        uint256 veryRareRewardPerSecond = very_rare_reward.div(86400);
        uint256 rareRewardPerSecond = rare_reward.div(86400);
        uint256 normalRewardPerSecond = normal_reward.div(86400);

        uint256 staked_nfts = 0;
        uint256 rewards = 0;
        uint256 amount = 0;
        uint256 fee = 0;
        for(uint256 i = 0; i < stakeTokens[msg.sender].length; i++) {
            if(isStaked[stakeTokens[msg.sender][i].tokenId] == 1) {
                staked_nfts = staked_nfts.add(1);
                uint256 claimedTime = block.timestamp - stakeTokens[msg.sender][i].lastClaimedTime;

                if(tokenInfo[stakeTokens[msg.sender][i].tokenId] == 1) {
                    amount = superRareRewardPerSecond.mul(claimedTime);
                    fee = claimedTime <= 2 minutes ? fee.add(amount * 50 / 100) : 0;
                    rewards = rewards.add(amount - fee);
                    stakeTokens[msg.sender][i].claimedBalance += (amount - fee);
                } else if (tokenInfo[stakeTokens[msg.sender][i].tokenId] == 2) {
                    amount = veryRareRewardPerSecond.mul(claimedTime);
                    fee = claimedTime <= 2 minutes ? fee.add(amount * 50 / 100) : 0;
                    rewards = rewards.add(amount - fee);
                    stakeTokens[msg.sender][i].claimedBalance += (amount - fee);
                } else if (tokenInfo[stakeTokens[msg.sender][i].tokenId] == 3) {
                    amount = rareRewardPerSecond.mul(claimedTime);
                    fee = claimedTime <= 2 minutes ? fee.add(amount * 50 / 100) : 0;
                    rewards = rewards.add(amount - fee);
                    stakeTokens[msg.sender][i].claimedBalance += (amount - fee);
                } else {
                    amount = normalRewardPerSecond.mul(claimedTime);
                    fee = claimedTime <= 2 minutes ? fee.add(amount * 50 / 100) : 0;
                    rewards = rewards.add(amount - fee);
                    stakeTokens[msg.sender][i].claimedBalance += (amount - fee);
                }
                stakeTokens[msg.sender][i].lastClaimedTime = block.timestamp;
            }
        }
        require(rewards > 0, "You didn't earn reward coins");
        if(staked_nfts >= 10) {
            rewards = rewards.mul(2);
            fee = fee.mul(2);
        }

        ERC20(coinAddress).transferFrom(adminAddress, msg.sender, rewards);
        userRewardBalance[msg.sender] = userRewardBalance[msg.sender].add(rewards);

        emit claimed(msg.sender, rewards, fee);

        uint256[] memory retValue = new uint256[](2);
        retValue[0] = block.timestamp;
        retValue[1] = rewards;
        return retValue;
    }

    function getRewardsByUser() public view returns (uint256) {
        return userRewardBalance[msg.sender];
    }

    function getClaimedRewardsByUser(address _addr) public view returns (uint256[] memory) {

        uint256 superRareRewardPerSecond = super_rare_reward.div(86400);
        uint256 veryRareRewardPerSecond = very_rare_reward.div(86400);
        uint256 rareRewardPerSecond = rare_reward.div(86400);
        uint256 normalRewardPerSecond = normal_reward.div(86400);

        uint256 staked_nfts = 0;
        uint256 rewards = 0;
        uint256 rewardsPerSecond = 0;
        uint256 claimedTime = 0;
        stakeTokenInfo[] memory stakeData = stakeTokens[_addr];
        for(uint256 i = 0; i < stakeData.length; i++) {
            if(isStaked[stakeData[i].tokenId] == 1) {
                staked_nfts = staked_nfts.add(1);
                claimedTime = block.timestamp - stakeData[i].lastClaimedTime;

                if(tokenInfo[stakeData[i].tokenId] == 1) {
                    rewardsPerSecond = rewardsPerSecond.add(superRareRewardPerSecond);
                    rewards = claimedTime <= 2 minutes ? rewards.add(superRareRewardPerSecond * claimedTime * 50 / 100) : rewards.add(superRareRewardPerSecond * claimedTime);
                } else if (tokenInfo[stakeData[i].tokenId] == 2) {
                    rewardsPerSecond = rewardsPerSecond.add(veryRareRewardPerSecond);
                    rewards = claimedTime <= 2 minutes ? rewards.add(veryRareRewardPerSecond * claimedTime * 50 / 100) : rewards.add(veryRareRewardPerSecond * claimedTime);
                } else if (tokenInfo[stakeData[i].tokenId] == 3) {
                    rewardsPerSecond = rewardsPerSecond.add(rareRewardPerSecond);
                    rewards = claimedTime <= 2 minutes ? rewards.add(rareRewardPerSecond * claimedTime * 50 / 100) : rewards.add(rareRewardPerSecond * claimedTime);
                } else {
                    rewardsPerSecond = rewardsPerSecond.add(normalRewardPerSecond);
                    rewards = claimedTime <= 2 minutes ? rewards.add(normalRewardPerSecond * claimedTime * 50 / 100) : rewards.add(normalRewardPerSecond * claimedTime);
                }
            }
        }
        if(staked_nfts >= 10) {
            rewards = rewards.mul(2);
        }
        uint256[] memory retValue = new uint256[](2);
        retValue[0] = rewards;
        retValue[1] = rewardsPerSecond;
        return retValue;
    }
}
