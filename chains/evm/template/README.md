# EVM Incident Template

Copy this directory into `chains/evm/<slug>/` when starting a new EVM investigation.

## Included

- `foundry.toml`: shared Foundry defaults.
- `src/target/Target.sol`: placeholder target contract or interface.
- `test/helpers/BaseForkTest.sol`: reusable fork bootstrap.
- `test/poc/01_ReproduceState.t.sol`: starter PoC scaffold.
- `config/`: address and fork metadata placeholders.

## Replace First

- `Target` with the project-specific contract or interface name.
- `mainnet` with the correct RPC alias.
- block number and protocol addresses in `config/`.
