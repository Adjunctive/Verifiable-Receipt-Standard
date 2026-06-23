// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAttestationRegistry — issuer-identity attestations (VRS spec §8).
/// @notice Turns "a key signed" into "an attested merchant/manufacturer/…".
///         Verifier-relative: each consumer chooses which attesters it accepts.
///         Roles are bytes32 tags, e.g. keccak256("merchant").
interface IAttestationRegistry {
    event Attested(
        address indexed attester, address indexed subject, bytes32 indexed role, uint64 validFrom, uint64 validUntil
    );
    event Revoked(address indexed attester, address indexed subject, bytes32 indexed role, uint64 at);

    error BadWindow();

    /// @notice Attest that `subject` holds `role` for [validFrom, validUntil).
    function attest(address subject, bytes32 role, uint64 validFrom, uint64 validUntil) external;

    /// @notice Revoke the caller's attestation of (`subject`, `role`).
    function revoke(address subject, bytes32 role) external;

    /// @notice Was (`subject`, `role`) attested by `attester` and valid at `at`?
    function isAttested(address subject, bytes32 role, address attester, uint64 at) external view returns (bool);
}
