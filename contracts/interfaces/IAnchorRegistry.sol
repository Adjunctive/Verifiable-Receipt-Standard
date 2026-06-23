// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAnchorRegistry — proven-time anchoring (VRS spec §15, §6.5).
/// @notice Anchoring a root upgrades asserted `issuedAt` to proven time: a root
///         anchored at block B demonstrably existed by B. Anchor-batch trees use
///         the T_ANODE tag, structurally distinct from receipt trees.
interface IAnchorRegistry {
    event Anchored(bytes32 indexed root, address submitter);

    /// @notice Record `root` as existing at the current block timestamp.
    function anchor(bytes32 root) external;

    /// @notice The timestamp at which `root` was anchored, or 0 if never.
    function anchoredAt(bytes32 root) external view returns (uint64);
}
