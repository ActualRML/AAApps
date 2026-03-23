// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../events/Events.sol" as Ev;
import "../libraries/SignatureChecker.sol";

import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

/**
 * @title SmartAccount
 * @dev Account Abstraction wallet featuring Social Recovery and EIP-712 execution.
 */
contract SmartAccount is Ev.Events, IAccount {
    // --- SECURITY & ERRORS ---
    error Reentrancy();
    bool private _locked;

    address public owner;
    uint256 public nonce;
    
    IEntryPoint public immutable entryPoint;

    mapping(address => bool) public isGuardian;
    uint256 public guardianCount;
    uint256 public immutable RECOVERY_THRESHOLD; 

    bytes32 private immutable DOMAIN_SEPARATOR;
    bytes32 private constant EXECUTE_TYPEHASH = keccak256(
        "Execute(address target,uint256 value,bytes data,uint256 nonce)"
    );
    bytes32 private constant EXECUTE_BATCH_TYPEHASH = keccak256(
        "ExecuteBatch(address[] targets,uint256[] values,bytes[] datas,uint256 nonce)"
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _owner, address[] memory _guardians, address _entryPoint) {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        entryPoint = IEntryPoint(_entryPoint);

        for (uint i = 0; i < _guardians.length; i++) {
            if (_guardians[i] != address(0) && !isGuardian[_guardians[i]]) {
                isGuardian[_guardians[i]] = true;
                guardianCount++;
            }
        }

        RECOVERY_THRESHOLD = _guardians.length;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SmartAccount")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    receive() external payable {
        if (msg.value > 0) emit Ev.Events.Deposit(msg.sender, msg.value);
    }

    /**
     * @dev ERC-4337 validation function. Validates the signature and handles gas pre-payment.
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        require(msg.sender == address(entryPoint), "Not EntryPoint");

        // Validate owner signature against userOpHash
        if (!SignatureChecker.isValidSignatureNow(owner, userOpHash, userOp.signature)) {
            return 1; // SIG_FAILED
        }

        // Refund gas funds to EntryPoint if required
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds
            }("");
            (success);
        }

        return 0; // SUCCESS
    }

    /**
     * @dev Social recovery mechanism allows guardians to reset the owner.
     */
    function recoverAccount(address _newOwner, bytes[] calldata signatures) external {
        require(signatures.length >= RECOVERY_THRESHOLD, "Need more signatures");
        require(signatures.length > 0, "No signatures provided");
        require(_newOwner != address(0), "Invalid new owner");

        bytes32 messageHash = keccak256(abi.encodePacked(_newOwner, address(this)));
    
        address lastSigner = address(0);
        for (uint i = 0; i < signatures.length; i++) {
            address signer = SignatureChecker.recoverSigner(messageHash, signatures[i]);
            
            require(isGuardian[signer], "Not a guardian");
            require(signer > lastSigner, "Duplicate/Unordered signer"); 
            lastSigner = signer;
        }

        owner = _newOwner;
    }

    /**
     * @dev Direct execution by the owner.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external nonReentrant returns (bytes memory) {
        require(msg.sender == owner || msg.sender == address(entryPoint), "Not authorized");
        return _call(target, value, data, nonce++);
    }

    /**
     * @dev Execution via EIP-712 off-chain signature.
     */
    function executeWithSignature(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 _nonce,
        bytes calldata signature
    ) external nonReentrant returns (bytes memory) {
        require(_nonce == nonce, "Invalid nonce");

        bytes32 structHash = keccak256(
            abi.encode(EXECUTE_TYPEHASH, target, value, keccak256(data), _nonce)
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        require(SignatureChecker.isValidSignatureNow(owner, hash, signature), "Invalid signature");

        bytes memory result = _call(target, value, data, nonce++);
        emit Ev.Events.UserOperationExecuted(msg.sender, _nonce, result);
        return result;
    }

    /**
     * @dev Batch execution of multiple calls by the owner.
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external onlyOwner nonReentrant returns (bytes[] memory) {
        require(targets.length == values.length && targets.length == datas.length, "Array mismatch");
        
        bytes[] memory results = new bytes[](targets.length);
        uint256 currentNonce = nonce;

        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = _call(targets[i], values[i], datas[i], currentNonce);
        }

        nonce++; 
        return results;
    }

    /**
     * @dev Batch execution via EIP-712 off-chain signature.
     */
    function executeBatchWithSignature(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 _nonce,
        bytes calldata signature
    ) external nonReentrant returns (bytes[] memory) {
        require(_nonce == nonce, "Invalid nonce");
        require(targets.length == values.length && targets.length == datas.length, "Array mismatch");

        bytes32 structHash = keccak256(
            abi.encode(
                EXECUTE_BATCH_TYPEHASH,
                keccak256(abi.encode(targets)),
                keccak256(abi.encode(values)),
                keccak256(abi.encode(datas)),
                _nonce
            )
        );
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        require(SignatureChecker.isValidSignatureNow(owner, hash, signature), "Invalid signature");

        bytes[] memory results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = _call(targets[i], values[i], datas[i], _nonce);
        }

        nonce++; 
        emit Ev.Events.UserOperationExecuted(msg.sender, _nonce, abi.encode(results));
        return results;
    }

    /**
     * @dev Internal helper for low-level calls.
     */
    function _call(
        address target, 
        uint256 value, 
        bytes memory data, 
        uint256 currentNonce
    ) internal returns (bytes memory) {
        require(target != address(0), "Invalid target");
        require(address(this).balance >= value, "Insufficient balance");

        (bool success, bytes memory result) = target.call{value: value}(data);
        
        if (!success) {
            if (result.length > 0) {
                assembly {
                    let size := mload(result)
                    revert(add(result, 32), size)
                }
            } else {
                revert("Transaction failed");
            }
        }

        emit Ev.Events.Executed(msg.sender, target, value, data, currentNonce);
        return result;
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Helper function for testing to get the immutable DOMAIN_SEPARATOR.
     */
    function getDomainSeparator() external view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }
}