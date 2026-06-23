// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRSTypes} from "./VRSTypes.sol";

/// @title IReceiptVerifier — stateless line-item proof verifier (spec §9.3, §18).
/// @notice Verifies an L1 line-item proof (issuer signature + Merkle path +
///         delegation) against this verifier's attester policy and ROLE, and
///         returns the facts a consuming contract needs. A key delegated for one
///         role cannot act in another (DelegateRoleForbidden).
interface IReceiptVerifier {
    error NotAttested();
    error NotAnchored();
    error NoAttesters();
    error DelegateRoleForbidden();

    /// @notice The issuer role this verifier accepts (e.g. keccak256("merchant")).
    function ROLE() external view returns (bytes32);

    /// @notice The accepted attester set.
    function attesters() external view returns (address[] memory);

    /// @notice Verify a line-item proof. `anchor*` are an optional proven-time
    ///         proof; pass (0,0,[]) to skip. Reverts on any failure.
    /// @return entId        registry key for this line item
    /// @return productIdHash keccak256 of the disclosed productId
    /// @return identity     EFFECTIVE identity (delegation root when delegated)
    /// @return issuedAt     the receipt's asserted issuance time
    /// @return anchoredTime proven time if an anchor proof was supplied, else 0
    function verifyLineItem(
        VRSTypes.HeaderDisclosure calldata h,
        VRSTypes.CoreDisclosure calldata c,
        bytes32 anchorRoot,
        uint256 anchorIndex,
        bytes32[] calldata anchorPath
    ) external view returns (bytes32 entId, bytes32 productIdHash, address identity, uint64 issuedAt, uint64 anchoredTime);
}
