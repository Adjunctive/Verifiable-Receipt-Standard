// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title VRSTypes — shared data types for the VRS contract interfaces.
/// @notice These structs and enums define the ABI surface only. Field ORDER
///         and TYPES are normative (they determine function selectors and ABI
///         encoding) and MUST match VRSLib byte-for-byte; field names are
///         documentation. No logic lives here. See the VRS Specification §6
///         (cryptographic constructions) and §14 (entitlement registry).
library VRSTypes {
    /// @notice Entitlement lifecycle state. `Unregistered` (0) is frozen.
    enum Status {
        Unregistered,
        Active,
        Returned,
        Voided,
        Stolen
    }

    /// @notice Manufacturer batch disclosure regime (MintAllowanceRegistry).
    enum DisclosureRegime {
        Transparent,
        ConfidentialAmount,
        Shielded,
        OffchainGrant
    }

    /// @notice Binds a receipt root to its issuer WITHOUT disclosing any line
    ///         (registration, spec §14). `issuerSig` is the receipt-commitment
    ///         signature; delegation fields are zero/empty when undelegated.
    struct IssuerBinding {
        bytes32 receiptRoot;
        bytes32 schemaHash;
        bytes issuerSig;
        address rootIdentity; // address(0) = undelegated
        bytes32 delegRole;
        uint64 delegValidFrom;
        uint64 delegValidUntil;
        bytes rootSig;
    }

    /// @notice Header disclosure for an L1 line-item proof (spec §9.2).
    struct HeaderDisclosure {
        address issuer; // signing key (operational key when delegated)
        uint64 issuedAt;
        uint8 receiptType;
        bytes32 fiscalHash;
        bytes32 schemaHash;
        bytes issuerSig; // EIP-712 over commitmentDigest(receiptRoot, schemaHash)
        bytes32[] headerPath; // Merkle path for leaf index 0
        address rootIdentity; // address(0) = no delegation
        bytes32 delegRole;
        uint64 delegValidFrom;
        uint64 delegValidUntil;
        bytes rootSig; // root's signature over the DelegationCert
    }

    /// @notice Core (and group-hash) disclosure for one line item (spec §9.2).
    struct CoreDisclosure {
        uint256 lineIndex; // 0-based; leaf index = lineIndex + 1
        bytes productId;
        uint256 qtyMilli;
        bytes32 saltCommit; // keccak256(abi.encode(T_SC, salt)); never the salt
        bytes32 commercialHash;
        bytes32 warrantyHash;
        bytes32 descriptiveHash;
        bytes32 provenanceHash;
        bytes32[] itemPath;
    }
}
