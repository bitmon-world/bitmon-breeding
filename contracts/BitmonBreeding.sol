pragma solidity ^0.5.0;

import "@openzeppelin/contracts/access/roles/MinterRole.sol";
import "../bitmon/contracts/BitmonCore.sol";


/**
 * @title BitmonBreeding
 * @dev The BitmonBreeding contracts is an algorithm to generate new bitmon ADN based on father and mother properties.
 * @author Enrique Berrueta eabz@polispay.org
 */


contract BitmonBreeding is MinterRole, BitmonBase, Seriality {
    string public constant name = "BitmonBreeding";
    string public constant symbol = "BMB";

    address public randomContractAddr;
    BitmonCore private bitmonContract;

    function setRandomContractAddr(address _addr) external onlyMinter returns (bool) {
        randomContractAddr = _addr;
        return true;
    }

    function setBitmonAddr(address _addr) external onlyMinter {
        bitmonContract = BitmonCore(_addr);
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

    function ser(Bitmon memory bitmon) private pure returns (uint256) {
        bytes memory b = new bytes(32);
        uintToBytes(32, bitmon.bitmonId, b);
        uintToBytes(28, bitmon.fatherId, b);
        uintToBytes(24, bitmon.motherId, b);
        uintToBytes(20, bitmon.birthHeight, b);
        uintToBytes(16, bitmon.gender, b);
        uintToBytes(15, bitmon.nature, b);
        uintToBytes(14, bitmon.specimen, b);
        uintToBytes(13, bitmon.variant, b);
        uintToBytes(12, bitmon.purity, b);
        uintToBytes(11, bitmon.generation, b);
        uintToBytes(10, bitmon.h, b);
        uintToBytes(9, bitmon.a, b);
        uintToBytes(8, bitmon.sa, b);
        uintToBytes(7, bitmon.d, b);
        uintToBytes(6, bitmon.sd, b);
        return 0;
    }

    function deser(uint256 tokenID) private view returns (Bitmon memory) {
        bytes memory b = new bytes(32);
        uint256 serialized = bitmonContract.getSerializedBitmon(tokenID);
        uintToBytes(32, serialized, b);
        Bitmon memory _bitmon;
        _bitmon.bitmonId = bytesToUint32(32, b);
        _bitmon.fatherId = bytesToUint32(28, b);
        _bitmon.motherId = bytesToUint32(24, b);
        _bitmon.birthHeight = bytesToUint32(20, b);
        _bitmon.gender = bytesToUint8(16, b);
        _bitmon.nature = bytesToUint8(15, b);
        _bitmon.specimen = bytesToUint8(14, b);
        _bitmon.variant = bytesToUint8(13, b);
        _bitmon.purity = bytesToUint8(12, b);
        _bitmon.generation = bytesToUint8(11, b);
        _bitmon.h = bytesToUint8(10, b);
        _bitmon.a = bytesToUint8(9, b);
        _bitmon.sa = bytesToUint8(8, b);
        _bitmon.d = bytesToUint8(7, b);
        _bitmon.sd = bytesToUint8(6, b);
        return _bitmon;
    }

    function breedBitmon(address to, uint256 fatherId, uint256 motherId) external returns (uint256) {
        require(bitmonContract.ownerOf(fatherId) == msg.sender, "ERC721: Father doesn't exists");
        require(bitmonContract.ownerOf(motherId) == msg.sender, "ERC721: Mother doesn't exists");
        Bitmon memory m = deser(motherId);
        Bitmon memory f = deser(fatherId);
        require(f.specimen == m.specimen, "ERC721: Mother doesn't exists");

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

        uint256 tokenId = bitmonContract.createChildBitmon(ser(child), msg.sender);

        return tokenId;
    }
}
