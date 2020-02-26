pragma solidity ^0.5.0;

import "@openzeppelin/contracts/access/roles/MinterRole.sol";
import "./utils/seriality/Seriality.sol";

/**
 * @title BitmonBreeding
 * @dev The BitmonBreeding contracts is an algorithm to generate new bitmon ADN based on father and mother properties.
 * @author Enrique Berrueta eabz@polispay.org
 */


contract BitmonBreeding is MinterRole {
    string public constant name = "BitmonBreeding";
    string public constant symbol = "BMB";

    address public randomContractAddr;

    function setRandomContractAddr(address _addr) external onlyMinter returns (bool) {
        randomContractAddr = _addr;
        return true;
    }

    function random() internal returns (uint8) {
        require(randomContractAddr != address(0), "contract address is not defined");
        (bool success, bytes memory data) = randomContractAddr.call(abi.encodeWithSignature("randomUint8()"));
        require(success, "contract call failed");
        uint8 randomN = bytesToUint8(data.length, data);
        while (randomN > 30) {
            randomN /= 3;
        }
        return randomN;
    }

    function clamp(uint8 min, uint8 max, int16 val) internal pure returns (uint8) {
        return (val < min ? min : (val > max ? max : uint8(val)));
    }

    function calcTrait(uint8 purity, uint8 parent1, uint8 parent2, int16 denom, uint8 min, uint8 max) internal returns (uint8) {
        int16 traitUnclamped = random(); // [0, 255]
        traitUnclamped -= 127;           // [-127, 128]
        traitUnclamped *= int16(purity)/denom;    // [-purity/denom, purity/denom]
        traitUnclamped += parent1 / 2 + parent2 / 2;
        return clamp(min, max, traitUnclamped);
    }

    function calcVariant(uint8 fVariant, uint8 mVariant) internal returns (uint8){
        uint8 variant = 0;
        uint8 specialChance = 3;
        if (fVariant == 1) {
            specialChance += 12;
        }
        if (mVariant == 1) {
            specialChance += 12;
        }
        if (random() < specialChance) {
            variant = 1;
        } else if (random() < 13) {
            variant = 2;
        }
        return variant;
    }

    function breedBitmon(address to, uint256 fatherId, uint256 motherId) external returns (uint256) {
        require(_exists(fatherId), "ERC721: Father doesn't exists");
        require(_exists(motherId), "ERC721: Mother doesn't exists");
        Bitmon memory m = _deserializeBitmon(motherId);
        Bitmon memory f = _deserializeBitmon(fatherId);
        require(f.specimen == m.specimen, "ERC721: Mother doesn't exists");
        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId, "");

        uint32 bitmonId = m.bitmonId;
        if (random() < 128) {
            bitmonId = f.bitmonId;
        }

        uint8 purity = f.purity / 2 + m.purity / 2;
        if (random() < 128) {
            purity = purity > 1 ? purity - purity / 10 - 1 : 0;
        }

        Bitmon memory child = Bitmon({
            bitmonId: bitmonId,
            fatherId: uint32(fatherId),
            motherId: uint32(motherId),
            birthHeight: uint32(block.number),
            gender: random() < 128 ? 1 : 0,
            nature: calcTrait(purity, f.nature, m.nature, 384, 0, 30),
            variant: calcVariant(f.variant, m.variant),
            purity: purity,
            specimen: f.specimen,
            generation: f.generation + 1,
            h: calcTrait(purity, f.h, m.h, 640, 0, 100),
            a: calcTrait(purity, f.a, m.a, 640, 0, 100),
            sa: calcTrait(purity, f.sa, m.sa, 640, 0, 100),
            d: calcTrait(purity, f.d, m.d, 640, 0, 100),
            sd: calcTrait(purity, f.sd, m.sd, 640, 0, 100)
        });

        bitmons[tokenId] = _serializeBitmon(child);

        return tokenId;
    }
}
