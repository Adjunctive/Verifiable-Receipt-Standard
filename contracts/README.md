# VRS Contracts — ABIs and Conformance Tests

The canonical on-chain surface of the **VRS Ethereum State Profile**, plus an
implementation-agnostic conformance suite. This package contains **interfaces
(the ABI) and tests only** — *not* a contract implementation. The reference
implementation lives in [`../../Reference/04-reference-contracts/src`](../../Reference/04-reference-contracts/src).

See the [VRS Specification](../02-vrs-specification.html) §13–§18 and Appendix B.

## Layout

```
interfaces/   canonical Solidity interfaces (the normative ABI)
  VRSTypes.sol              structs & enums (field order/types are normative)
  IAttestationRegistry.sol  issuer identity (spec §8)
  IAnchorRegistry.sol       proven time (spec §15)
  IEntitlementRegistry.sol  ownership / status / lifecycle (spec §14)
  IReceiptVerifier.sol      stateless proof verifier (spec §9.3, §18)
  IMintAllowanceRegistry.sol manufacturer batches & serial nullifiers (spec §16)
  INoticeRegistry.sol       batch-keyed recall notices (spec §17, DRAFT)
abi/          JSON ABIs generated from the interfaces (forge inspect)
test/         VRSConformance.t.sol — abstract conformance suite
foundry.toml  build config (solc 0.8.28, optimizer + via_ir)
```

## ABIs

The JSON ABIs in `abi/` are generated from the interfaces:

```sh
forge build
for C in IAttestationRegistry IAnchorRegistry IEntitlementRegistry \
         IReceiptVerifier IMintAllowanceRegistry INoticeRegistry; do
  forge inspect "$C" abi --json > "abi/$C.json"
done
```

Each interface's selectors have been checked to match the reference
implementation exactly (no missing methods, no selector mismatches), so a
contract that implements an interface is ABI-compatible with the reference.

## Conformance tests

`test/VRSConformance.t.sol` is an **abstract** Foundry test. It builds valid
inputs with the canonical `VRSLib` (pure cryptography — not a registry
implementation) and exercises the required behaviours of a conforming Ethereum
State Profile deployment: registration (issuer binding + bearer authority),
`firstHolder` immutability, transfer and `transferWithAuth`, stolen/clear, void,
`recordEvent`, attestation windows, anchoring, the set-once serial nullifier
(cloned-serial revert), `verifyLineItem`, and the delegate-role guard.

To run it against **your** implementation, subclass it and implement the five
deploy hooks:

```solidity
import {VRSConformance} from ".../VRSConformance.t.sol";

contract MyImplConformance is VRSConformance {
    function deployEntitlementRegistry() internal override returns (IEntitlementRegistry) {
        return IEntitlementRegistry(address(new MyEntitlementRegistry()));
    }
    // …deployAttestationRegistry / deployAnchorRegistry /
    //   deployMintAllowanceRegistry / deployReceiptVerifier
}
```

```sh
forge test
```

The suite has been validated to pass (13/13) against the reference
implementation; that validation harness is intentionally not shipped here so the
package stays implementation-free.

## Build notes

- `solc 0.8.28`, optimizer on, **`via_ir = true`** (the input-builder helper is
  stack-heavy without it).
- `foundry.toml` remaps `forge-std/` and `vrs-ref/` (the canonical `VRSLib`) into
  the repo's `Reference/04-reference-contracts`. Distributing this package
  stand-alone would require vendoring those two dependencies.
