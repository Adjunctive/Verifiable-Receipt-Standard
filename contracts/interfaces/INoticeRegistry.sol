// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title INoticeRegistry — batch-keyed recall / broadcast notices (spec §17, DRAFT).
/// @notice Anchors a signed notice hash under a manufacturing batch so holder
///         wallets discover it by the batches they hold. The notice names no
///         owner and carries no contact detail; the caller MUST be attested for
///         the batch (manufacturer/grant-chain) or hold a recall role the
///         verifier accepts. This profile is draft and not yet in the reference
///         contracts.
interface INoticeRegistry {
    event Recalled(bytes32 indexed batchId, bytes32 noticeHash, address indexed issuerRoot, uint8 severity);

    error NotAuthorisedForBatch();

    /// @notice Publish a recall notice for `batchId`. `severity` is a profile
    ///         code (e.g. 0=informational, 1=advisory, 2=safety).
    function recall(bytes32 batchId, bytes32 noticeHash, uint8 severity) external;

    /// @notice Notice hashes recorded against `batchId`, in publication order.
    function recallsOf(bytes32 batchId) external view returns (bytes32[] memory);
}
