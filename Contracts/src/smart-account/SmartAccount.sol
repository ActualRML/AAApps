// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Errors} from "../common/Errors.sol";

/**
 * @title SmartAccount
 * @dev Gas-optimized ERC-4337 smart account dengan Social Recovery.
 * @notice Menggunakan transient storage (EIP-1153) untuk reentrancy guard.
 */
contract SmartAccount is IAccount {
    // ============ CONSTANTS ============
    bytes32 private constant _NAME_HASH = keccak256("SmartAccount");
    bytes32 private constant _VERSION_HASH = keccak256("1");
    bytes32 private constant _TYPEHASH_EIP712DOMAIN = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _EXECUTE_TYPEHASH = keccak256(
        "Execute(address target,uint256 value,bytes data,uint256 nonce)"
    );

    // Transient storage slot constants (EIP-1153)
    uint256 private constant _REENTRANCY_SLOT = 0;
    uint256 private constant _LOCKED = 1;
    uint256 private constant _UNLOCKED = 0;

    // ============ STORAGE ============
    bool private _initialized;
    
    address public owner;
    uint256 public nonce;
    IEntryPoint public entryPoint;
    
    mapping(address => uint256) public guardianIndex; 
    uint256 public guardianBitmap;
    uint256 public guardianCount;
    uint256 public recoveryThreshold;

    // ============ MODIFIERS ============
    modifier nonReentrant() {
        assembly ("memory-safe") {
            if tload(_REENTRANCY_SLOT) {
                mstore(0x00, 0x48f5c3ed) // Reentrancy.selector
                revert(0x00, 0x04)
            }
            tstore(_REENTRANCY_SLOT, _LOCKED)
        }
        _;
        assembly ("memory-safe") {
            tstore(_REENTRANCY_SLOT, _UNLOCKED)
        }
    }

    // ============ CONSTRUCTOR ============
    constructor() {
        _initialized = true;
    }

    // ============ INITIALIZER ============
    function initialize(
        address _owner,
        address[] calldata _guardians,
        uint256 _threshold,
        address _entryPoint
    ) external {
        if (_initialized) revert Errors.AlreadyInitialized();
        if (_owner == address(0) || _entryPoint == address(0)) revert Errors.ZeroAddress();
        if (_threshold == 0 || _threshold > _guardians.length) revert Errors.InvalidThreshold();

        _initialized = true;
        owner = _owner;
        entryPoint = IEntryPoint(_entryPoint);
        recoveryThreshold = _threshold;

        uint256 bitmap;
        unchecked {
            for (uint256 i = 0; i < _guardians.length; ++i) {
                address g = _guardians[i];
                if (g == address(0)) revert Errors.ZeroAddress();
                if (guardianIndex[g] != 0) revert Errors.DuplicateSigner();
                
                guardianIndex[g] = i + 1;
                // forge-lint: disable-next-line(incorrect-shift)
                bitmap |= 1 << i;
            }
        }
        guardianBitmap = bitmap;
        guardianCount = _guardians.length;
    }

    receive() external payable {}

    // ============ EXECUTION ============
    function execute(address target, uint256 value, bytes calldata data) 
        external payable nonReentrant returns (bytes memory result) 
    {
        if (msg.sender != owner && msg.sender != address(entryPoint)) revert Errors.NotAuthorized();
        result = _executeCall(target, value, data, nonce);
        nonce++;
    }

    function executeWithSignature(
        address target, 
        uint256 value, 
        bytes calldata data, 
        uint256 _nonce, 
        bytes calldata signature
    ) external nonReentrant returns (bytes memory result) {
        if (_nonce != nonce) revert Errors.InvalidNonce();

        bytes32 structHash = keccak256(
            abi.encode(_EXECUTE_TYPEHASH, target, value, keccak256(data), _nonce)
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));

        // tryRecover return (address, ECDSA.RecoverError, bytes32)
        (address signer, ECDSA.RecoverError error,) = ECDSA.tryRecover(hash, signature);
        if (error != ECDSA.RecoverError.NoError || signer != owner) revert Errors.InvalidSignature();

        result = _executeCall(target, value, data, nonce);
        nonce++;
    }

    // ============ ERC-4337 ============
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        if (msg.sender != address(entryPoint)) revert Errors.NotEntryPoint();

        // tryRecover return (address, ECDSA.RecoverError, bytes32)
        (address signer, ECDSA.RecoverError error,) = ECDSA.tryRecover(userOpHash, userOp.signature);
        
        if (error != ECDSA.RecoverError.NoError || signer != owner) {
            return 1; // SIG_VALIDATION_FAILED
        }

        if (missingAccountFunds > 0) {
            assembly ("memory-safe") {
                pop(call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0))
            }
        }
        return 0;
    }

    // ============ SOCIAL RECOVERY ============
    function recoverAccount(
        address _newOwner,
        bytes[] calldata signatures,
        uint256[] calldata indices
    ) external {
        uint256 sigLen = signatures.length;
        if (sigLen < recoveryThreshold) revert Errors.ThresholdNotMet();
        if (_newOwner == address(0)) revert Errors.ZeroAddress();
        if (indices.length != sigLen) revert Errors.ArrayMismatch();

        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(_newOwner, address(this), block.chainid))
        ));

        uint256 usedBitmap;
        uint256 currentGuardianBitmap = guardianBitmap;

        unchecked {
            for (uint256 i = 0; i < sigLen; ++i) {
                // forge-lint: disable-next-line(incorrect-shift)
                uint256 idx = indices[i];
                uint256 bit = 1 << idx;
                
                if ((usedBitmap & bit) != 0) revert Errors.DuplicateSigner();
                usedBitmap |= bit;
                
                if ((currentGuardianBitmap & bit) == 0) revert Errors.NotGuardian();
                
                // tryRecover return (address, ECDSA.RecoverError, bytes32)
                (address signer, ECDSA.RecoverError error,) = ECDSA.tryRecover(messageHash, signatures[i]);
                if (error != ECDSA.RecoverError.NoError || guardianIndex[signer] != idx + 1) revert Errors.InvalidSignature();
            }
        }
        owner = _newOwner;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(
            _TYPEHASH_EIP712DOMAIN, _NAME_HASH, _VERSION_HASH, block.chainid, address(this)
        ));
    }

    // ============ INTERNAL ============
    function _executeCall(address target, uint256 value, bytes memory data, uint256) 
        internal returns (bytes memory result) 
    {
        if (target == address(0)) revert Errors.InvalidTarget();
        assembly ("memory-safe") {
            if lt(selfbalance(), value) {
                mstore(0x00, 0xcd786059) // InsufficientBalance.selector
                revert(0x00, 0x04)
            }
        }

        bool success;
        (success, result) = target.call{value: value}(data);
        if (!success) _bubbleRevert(result);
    }

    function _bubbleRevert(bytes memory result) internal pure {
        assembly ("memory-safe") {
            let size := mload(result)
            if gt(size, 0) { revert(add(result, 32), size) }
            revert(0, 0)
        }
    }

    /**
     * @notice Melakukan eksekusi banyak transaksi dalam satu batch.
     * @dev Gas dioptimasi dengan loop dan pengecekan length array.
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external payable nonReentrant {
        // 1. Cek Otoritas
        if (msg.sender != owner && msg.sender != address(entryPoint)) {
            revert Errors.NotAuthorized();
        }
        
        // 2. Cek Validitas Data
        uint256 len = dest.length;
        if (len != value.length || len != func.length) {
            revert Errors.ArrayMismatch();
        }

        // 3. Eksekusi loop
        for (uint256 i = 0; i < len; ) {
            _executeCall(dest[i], value[i], func[i], nonce);
            unchecked { ++i; } // Hemat gas untuk loop
        }

        // 4. Update Nonce (sekali saja untuk satu batch)
        nonce++;
    }
}