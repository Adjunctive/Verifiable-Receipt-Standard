// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VRSTypes} from "../interfaces/VRSTypes.sol";
import {IEntitlementRegistry} from "../interfaces/IEntitlementRegistry.sol";
import {IAttestationRegistry} from "../interfaces/IAttestationRegistry.sol";
import {IAnchorRegistry} from "../interfaces/IAnchorRegistry.sol";
import {IMintAllowanceRegistry} from "../interfaces/IMintAllowanceRegistry.sol";
import {IReceiptVerifier} from "../interfaces/IReceiptVerifier.sol";
// VRSLib is the canonical cryptographic core (pure functions), used only to
// construct valid test inputs — NOT a registry implementation.
import {VRSLib} from "vrs-ref/VRSLib.sol";

/// @title VRSConformance — implementation-agnostic conformance tests for the
///        VRS Ethereum State Profile (spec §13–§18).
/// @notice ABSTRACT. An implementer subclasses this and implements the deploy
///         hooks to point the suite at THEIR contracts; no implementation is
///         shipped here. Inputs are built with the canonical VRSLib so the
///         tests bind any conforming implementation to the frozen v1 commitments.
abstract contract VRSConformance is Test {
    // ── Deploy hooks — implement these against your contracts ──
    function deployAttestationRegistry() internal virtual returns (IAttestationRegistry);
    function deployAnchorRegistry() internal virtual returns (IAnchorRegistry);
    function deployEntitlementRegistry() internal virtual returns (IEntitlementRegistry);
    function deployMintAllowanceRegistry() internal virtual returns (IMintAllowanceRegistry);
    function deployReceiptVerifier(IAttestationRegistry att, IAnchorRegistry anc, bytes32 role, address[] memory atts)
        internal
        virtual
        returns (IReceiptVerifier);

    IAttestationRegistry att;
    IAnchorRegistry anc;
    IEntitlementRegistry reg;
    IMintAllowanceRegistry mar;

    bytes32 constant FISCAL = keccak256("conformance-fiscal");
    bytes32 constant SCHEMA = keccak256("vrs/receipt/1.0");
    bytes32 constant ROLE_MERCHANT = keccak256("merchant");
    bytes32 constant ROLE_COURIER = keccak256("courier");
    uint64 constant ISSUED = 1_790_000_000;

    address issuer; uint256 issuerPk;
    address holder; uint256 holderPk;
    address bob; uint256 bobPk;
    address opKey; uint256 opPk;

    function setUp() public virtual {
        (issuer, issuerPk) = makeAddrAndKey("issuer");
        (holder, holderPk) = makeAddrAndKey("holder");
        (bob, bobPk) = makeAddrAndKey("bob");
        (opKey, opPk) = makeAddrAndKey("opKey");
        att = deployAttestationRegistry();
        anc = deployAnchorRegistry();
        reg = deployEntitlementRegistry();
        mar = deployMintAllowanceRegistry();
    }

    // ───────────────────────── helpers ─────────────────────────
    function _one(bytes32 x) internal pure returns (bytes32[] memory a) { a = new bytes32[](1); a[0] = x; }
    function _empty() internal pure returns (bytes32[] memory a) { a = new bytes32[](0); }

    /// Build a minimal one-line receipt (core-only) signed by `sissuer`/`pk`,
    /// optionally delegated by `root`/`rootPk` for `role`. Returns the proof
    /// structs, the issuer binding, and the entitlement id.
    function _receipt(address sissuer, uint256 pk, address root, uint256 rootPk, bytes32 role)
        internal
        returns (
            VRSTypes.HeaderDisclosure memory h,
            VRSTypes.CoreDisclosure memory c,
            VRSTypes.IssuerBinding memory b,
            bytes32 salt,
            bytes32 entId
        )
    {
        salt = keccak256(abi.encodePacked("salt", sissuer));
        bytes32 sc = VRSLib.saltCommitOf(salt);
        bytes32 core = VRSLib.coreHash(0, bytes("gtin:09506000134352"), 1000, sc);
        bytes32 item = VRSLib.itemLeaf(core, VRSLib.ABSENT, VRSLib.ABSENT, VRSLib.ABSENT, VRSLib.ABSENT);

        bool delegated = root != address(0);
        uint64 vf = ISSUED - 1 days;
        uint64 vu = ISSUED + 1 days;
        bytes32 dHash = delegated ? VRSLib.delegationHash(root, role, vf, vu) : VRSLib.ABSENT;
        bytes32 hLeaf = VRSLib.headerLeaf(sissuer, ISSUED, 0, FISCAL, dHash);
        bytes32 receiptRoot = VRSLib.processProof(hLeaf, 0, _one(item)); // = node(hLeaf, item)

        bytes memory issuerSig;
        { (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, VRSLib.commitmentDigest(receiptRoot, SCHEMA));
          issuerSig = abi.encodePacked(r, s, v); }

        bytes memory rootSig;
        if (delegated) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(rootPk, VRSLib.delegationDigest(sissuer, role, vf, vu));
            rootSig = abi.encodePacked(r, s, v);
        }

        h = VRSTypes.HeaderDisclosure({
            issuer: sissuer, issuedAt: ISSUED, receiptType: 0, fiscalHash: FISCAL, schemaHash: SCHEMA,
            issuerSig: issuerSig, headerPath: _one(item),
            rootIdentity: delegated ? root : address(0), delegRole: delegated ? role : bytes32(0),
            delegValidFrom: delegated ? vf : 0, delegValidUntil: delegated ? vu : 0, rootSig: rootSig
        });
        c = VRSTypes.CoreDisclosure({
            lineIndex: 0, productId: bytes("gtin:09506000134352"), qtyMilli: 1000, saltCommit: sc,
            commercialHash: VRSLib.ABSENT, warrantyHash: VRSLib.ABSENT, descriptiveHash: VRSLib.ABSENT,
            provenanceHash: VRSLib.ABSENT, itemPath: _one(hLeaf)
        });
        b = VRSTypes.IssuerBinding({
            receiptRoot: receiptRoot, schemaHash: SCHEMA, issuerSig: issuerSig,
            rootIdentity: delegated ? root : address(0), delegRole: delegated ? role : bytes32(0),
            delegValidFrom: delegated ? vf : 0, delegValidUntil: delegated ? vu : 0, rootSig: rootSig
        });
        entId = VRSLib.entitlementId(receiptRoot, 0, sc);
    }

    function _registerToHolder() internal returns (bytes32 entId) {
        (, , VRSTypes.IssuerBinding memory b, bytes32 salt, bytes32 id) =
            _receipt(issuer, issuerPk, address(0), 0, bytes32(0));
        vm.prank(holder);
        reg.register(b, 0, salt);
        return id;
    }

    // ───────────────────────── EntitlementRegistry ─────────────────────────
    function test_register_setsState() public {
        bytes32 id = _registerToHolder();
        assertEq(reg.holderOf(id), holder, "holderOf");
        assertEq(reg.firstHolder(id), holder, "firstHolder");
        assertEq(uint8(reg.statusOf(id)), uint8(VRSTypes.Status.Active), "status Active");
        assertEq(reg.issuerOf(id), issuer, "issuer recovered from signature");
    }

    function test_revert_doubleRegister() public {
        (, , VRSTypes.IssuerBinding memory b, bytes32 salt,) = _receipt(issuer, issuerPk, address(0), 0, bytes32(0));
        vm.prank(holder); reg.register(b, 0, salt);
        vm.prank(holder); vm.expectRevert(); reg.register(b, 0, salt);
    }

    function test_firstHolder_immutableAcrossTransfer() public {
        bytes32 id = _registerToHolder();
        vm.prank(holder); reg.transfer(id, bob);
        assertEq(reg.holderOf(id), bob, "holder moved");
        assertEq(reg.firstHolder(id), holder, "firstHolder unchanged");
    }

    function test_revert_transferNotHolder() public {
        bytes32 id = _registerToHolder();
        vm.prank(bob); vm.expectRevert(); reg.transfer(id, bob);
    }

    function test_transferWithAuth() public {
        bytes32 id = _registerToHolder();
        bytes32 regDomTh = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 regDom = keccak256(abi.encode(regDomTh, keccak256("VRSRegistry"), keccak256("1"), block.chainid, address(reg)));
        uint64 deadline = ISSUED + 1000;
        bytes32 structHash = keccak256(abi.encode(reg.TRANSFER_AUTH_TYPEHASH(), id, bob, reg.transferNonce(id), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", regDom, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(holderPk, digest);
        reg.transferWithAuth(id, bob, deadline, abi.encodePacked(r, s, v)); // anyone may submit
        assertEq(reg.holderOf(id), bob, "transferWithAuth moved holder");
    }

    function test_stolen_then_clear() public {
        bytes32 id = _registerToHolder();
        vm.prank(holder); reg.flagStolen(id);
        assertEq(uint8(reg.statusOf(id)), uint8(VRSTypes.Status.Stolen), "Stolen");
        vm.prank(holder); reg.clearStolen(id);
        assertEq(uint8(reg.statusOf(id)), uint8(VRSTypes.Status.Active), "back to Active");
    }

    function test_void_byIssuer() public {
        bytes32 id = _registerToHolder();
        vm.prank(issuer); reg.void(id);
        assertEq(uint8(reg.statusOf(id)), uint8(VRSTypes.Status.Voided), "Voided");
    }

    function test_recordEvent_emits() public {
        bytes32 id = _registerToHolder();
        bytes32 ah = keccak256("attestation");
        vm.prank(holder);
        vm.expectEmit(true, false, false, true, address(reg));
        emit IEntitlementRegistry.LifecycleEvent(id, ah, holder);
        reg.recordEvent(id, ah);
    }

    // ───────────────────────── Attestation / Anchor ─────────────────────────
    function test_attest_isAttested_window() public {
        att.attest(issuer, ROLE_MERCHANT, ISSUED - 1, ISSUED + 100);
        assertTrue(att.isAttested(issuer, ROLE_MERCHANT, address(this), ISSUED), "valid in window");
        assertFalse(att.isAttested(issuer, ROLE_MERCHANT, address(this), ISSUED + 1000), "expired");
        att.revoke(issuer, ROLE_MERCHANT);
        assertFalse(att.isAttested(issuer, ROLE_MERCHANT, address(this), ISSUED), "revoked");
    }

    function test_anchor_anchoredAt() public {
        bytes32 root = keccak256("some-root");
        assertEq(anc.anchoredAt(root), 0, "not anchored");
        anc.anchor(root);
        assertGt(anc.anchoredAt(root), 0, "anchored");
    }

    // ───────────────────────── MintAllowance / nullifier ─────────────────────────
    function test_authenticate_setOnceNullifier() public {
        bytes memory serial = bytes("SER1234");
        bytes32 serialSalt = keccak256("serial-salt");
        bytes32 serialLeaf = keccak256(abi.encode(VRSLib.T_SERIAL, serial, serialSalt));
        bytes32 serialRoot = serialLeaf; // single-leaf batch
        bytes32 productClassHash = keccak256("gtin:09506000134352");
        vm.prank(issuer);
        bytes32 batchId = mar.createBatch(productClassHash, 1, serialRoot, VRSTypes.DisclosureRegime.OffchainGrant);
        bytes32 nf = keccak256(abi.encode(VRSLib.T_NULL, batchId, serial, serialSalt));
        assertFalse(mar.nullifierUsed(nf), "unused");
        mar.authenticate(batchId, serial, serialSalt, _empty(), 0, keccak256("entId"));
        assertTrue(mar.nullifierUsed(nf), "set once");
        vm.expectRevert(); // second use = cloned serial
        mar.authenticate(batchId, serial, serialSalt, _empty(), 0, keccak256("entId"));
    }

    // ───────────────────────── ReceiptVerifier ─────────────────────────
    function _verifier(bytes32 role) internal returns (IReceiptVerifier) {
        address[] memory atts = new address[](1); atts[0] = address(this);
        return deployReceiptVerifier(att, anc, role, atts);
    }

    function test_verifyLineItem_happy() public {
        IReceiptVerifier ver = _verifier(ROLE_MERCHANT);
        att.attest(issuer, ROLE_MERCHANT, ISSUED - 1, ISSUED + 1000);
        (VRSTypes.HeaderDisclosure memory h, VRSTypes.CoreDisclosure memory c,,, bytes32 expId) =
            _receipt(issuer, issuerPk, address(0), 0, bytes32(0));
        (bytes32 entId,, address identity,,) = ver.verifyLineItem(h, c, bytes32(0), 0, _empty());
        assertEq(entId, expId, "entId");
        assertEq(identity, issuer, "effective identity");
    }

    function test_revert_delegateRoleForbidden() public {
        IReceiptVerifier ver = _verifier(ROLE_MERCHANT);
        // root (issuer) attested for merchant, but the cert delegates COURIER.
        att.attest(issuer, ROLE_MERCHANT, ISSUED - 1, ISSUED + 1000);
        (VRSTypes.HeaderDisclosure memory h, VRSTypes.CoreDisclosure memory c,,,) =
            _receipt(opKey, opPk, issuer, issuerPk, ROLE_COURIER);
        vm.expectRevert(); // a key delegated for courier cannot act as merchant
        ver.verifyLineItem(h, c, bytes32(0), 0, _empty());
    }
}
