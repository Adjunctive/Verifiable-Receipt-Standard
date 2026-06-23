// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRSTypes} from "./VRSTypes.sol";

/// @title IMintAllowanceRegistry — manufacturer batches and serial authentication (spec §16).
/// @notice Batch creation, mint-allowance/distribution, and a set-once serial
///         nullifier (a second use of a serial reverts — the cloned-serial
///         signal). Proves serial/receipt/channel evidence, NOT physical
///         genuineness. Serial leaf = keccak256(abi.encode(T_SERIAL, serial,
///         serialSalt)); nullifier = keccak256(abi.encode(T_NULL, batchId,
///         serial, serialSalt)); batchId = keccak256(abi.encode(productClassHash,
///         manufacturerRoot, quantity, serialRoot)).
interface IMintAllowanceRegistry {
    event OperatorSet(address indexed root, address indexed operator, bool authorised);
    event BatchCreated(
        bytes32 indexed batchId, address indexed manufacturer, bytes32 productClassHash, uint64 quantity, bytes32 serialRoot
    );
    event AllowanceTransferred(bytes32 indexed batchId, address indexed from, address indexed to, uint64 amount);
    event Consumed(bytes32 indexed batchId, address indexed root, uint64 amount);
    event Authenticated(bytes32 indexed batchId, bytes32 indexed nullifier, bytes32 bindEntitlementId);

    error NoBatch();
    error BatchExists();
    error ZeroAddress();
    error InsufficientAllowance();
    error OffchainGrantNoOnchainAccounting();
    error SerialNotInBatch();
    error NullifierUsed();
    error OperatorConflict();
    error BadCommit();

    function setOperator(address operator, bool authorised) external;
    function rootOf(address key) external view returns (address);

    function createBatch(bytes32 productClassHash, uint64 quantity, bytes32 serialRoot, VRSTypes.DisclosureRegime regime)
        external
        returns (bytes32 batchId);
    function transferAllowance(bytes32 batchId, address to, uint64 amount) external;
    function consume(bytes32 batchId, uint64 amount) external;

    /// @notice Reveal the serial salt, prove serial ∈ serialRoot, set the
    ///         nullifier exactly once, and bind it to an entitlement.
    function authenticate(
        bytes32 batchId,
        bytes calldata serial,
        bytes32 serialSalt,
        bytes32[] calldata serialPath,
        uint256 serialIndex,
        bytes32 bindEntitlementId
    ) external;

    /// @notice commitment = keccak256(abi.encode(batchId, serial, serialSalt, bindEntitlementId, registrant)).
    function commitAuthentication(bytes32 commitment) external;
    function authenticateCommitted(
        bytes32 batchId,
        bytes calldata serial,
        bytes32 serialSalt,
        bytes32[] calldata serialPath,
        uint256 serialIndex,
        bytes32 bindEntitlementId
    ) external;

    function regimeOf(bytes32 batchId) external view returns (VRSTypes.DisclosureRegime);
    function batchManufacturer(bytes32 batchId) external view returns (address);
    function batchExists(bytes32 batchId) external view returns (bool);

    // ── Public mapping getters ──
    function allowanceOf(bytes32 batchId, address root) external view returns (uint64);
    function consumedOf(bytes32 batchId, address root) external view returns (uint64);
    function boundEntitlement(bytes32 nullifier) external view returns (bytes32);
    function nullifierUsed(bytes32 nullifier) external view returns (bool);
    function authenticateCommitAt(bytes32 commitment) external view returns (uint64);
    function operatorOf(address key) external view returns (address);
    function operatorCount(address key) external view returns (uint256);
}
