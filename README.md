# Verifiable Receipt Standard (VRS)

Receipts you can verify, keep private, and use long after the purchase — without
putting your basket on a public ledger, or pretending a blockchain can settle
who owns what. An open standard: no protocol fee, no token, no rent on the core.

**Status:** draft community specification — unaudited, not for production with
real value. The wire/commitment format is frozen as VRS major version 1.

## Documents

| | Document | |
|---|---|---|
| 01 | [Overview](01-vrs-overview.html) | concept, use-case walkthroughs, worked commitment tree |
| 02 | [Specification](02-vrs-specification.html) | normative, W3C-style |
| 03 | [Data Formats](03-vrs-data-formats.html) | canonical JSON for every document type |
| 04 | [Conformance Vectors](04-vrs-conformance-vectors.html) | byte-exact test fixtures |
| ◇ | [Contracts](contracts/) | Solidity interfaces (ABIs) + Foundry conformance suite |

When served over GitHub Pages these `.html` files are the live site; start at
[`index.html`](index.html).

## Implementing

Build against the **Specification** (02) and **Data Formats** (03); verify your
output against the **Conformance Vectors** (04). For on-chain components, the
canonical interfaces, JSON ABIs, and an implementation-agnostic Foundry
conformance suite are under [`contracts/`](contracts/).

> Note: `contracts/` is the ABI + tests only — *not* a contract implementation.
> Its Foundry build currently remaps `forge-std` and the canonical `VRSLib` from
> a sibling reference tree; to build it from this repo standalone, vendor those
> two dependencies (see `contracts/README.md`).

## License / stewardship

Open standard, royalty-free: no protocol fee, no token, no core rent.
