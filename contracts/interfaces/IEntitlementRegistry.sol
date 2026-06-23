// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRSTypes} from "./VRSTypes.sol";

/// @title IEntitlementRegistry — shared ownership/status/lifecycle state (spec §14).
/// @notice Consumer-pull registration (the issuer never transacts). Registration
///         binds the issuer from the receipt-commitment signature and the
///         entitlement id from the revealed bearer salt, writing only the opaque
///         receiptRoot and issuer identity (product-private). Registry-action
///         signatures are chain-bound (domain name "VRSRegistry").
interface IEntitlementRegistry {
    event OperatorSet(address indexed root, address indexed operator, bool authorised);
    event Registered(bytes32 indexed id, address indexed holder, address indexed issuerRoot);
    event Transferred(bytes32 indexed id, address indexed from, address indexed to);
    event StatusChanged(bytes32 indexed id, VRSTypes.Status status, address byRoot);
    event BearerReturned(bytes32 indexed id, address indexed issuerRoot, uint256 qtyMilli);
    event LifecycleEvent(bytes32 indexed id, bytes32 attestationHash, address submittedBy);

    error AlreadyRegistered();
    error NotRegistered();
    error NotHolder();
    error NotIssuer();
    error WrongStatus();
    error BadAuth();
    error ZeroAddress();
    error AlreadyReturnedBearer();
    error OperatorConflict();
    error Expired();
    error BadCommit();

    // ── Constants (auto-getters) ──
    function MIN_COMMIT_AGE() external view returns (uint64);
    function TRANSFER_AUTH_TYPEHASH() external view returns (bytes32);

    // ── Operator (delegate-key → root) management ──
    function setOperator(address operator, bool authorised) external;
    function rootOf(address key) external view returns (address);

    // ── Registration (consumer-pull; commit–reveal on public mempools) ──
    function register(VRSTypes.IssuerBinding calldata b, uint256 lineIndex, bytes32 salt) external;
    function commitRegistration(bytes32 commitment) external; // commitment = keccak256(abi.encode(salt, registrant))
    function registerCommitted(VRSTypes.IssuerBinding calldata b, uint256 lineIndex, bytes32 salt) external;

    // ── Transfer ──
    function transfer(bytes32 id, address to) external;
    function transferWithAuth(bytes32 id, address to, uint64 deadline, bytes calldata holderSig) external;

    // ── Status transitions ──
    function flagStolen(bytes32 id) external;
    function clearStolen(bytes32 id) external;
    function markReturned(bytes32 id) external;
    function markReturnedBearer(bytes32 id, uint256 qtyMilli) external;
    function void(bytes32 id) external;

    // ── Lifecycle ──
    function recordEvent(bytes32 id, bytes32 attestationHash) external;

    // ── Reads ──
    function holderOf(bytes32 id) external view returns (address);
    function firstHolder(bytes32 id) external view returns (address);
    function statusOf(bytes32 id) external view returns (VRSTypes.Status);
    function issuerOf(bytes32 id) external view returns (address);
    function isReturnedFor(bytes32 id, address issuerRoot) external view returns (bool);
    function isFullyReturnedBearer(bytes32 id, address issuerRoot, uint256 lineQtyMilli) external view returns (bool);
    function returnedQtyOf(bytes32 id, address issuerRoot) external view returns (uint256);

    // ── Public mapping getters ──
    function operatorOf(address key) external view returns (address);
    function operatorCount(address key) external view returns (uint256);
    function transferNonce(bytes32 id) external view returns (uint256);
    function registerCommitAt(bytes32 commitment) external view returns (uint64);
    function returnedQtyMilli(bytes32 id, address issuerRoot) external view returns (uint256);
}
