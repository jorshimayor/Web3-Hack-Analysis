# Web3 Hack Analysis Template

This scaffold turns a single-project audit repo into a reusable workspace for incident research across multiple chains.

## Goals

- Keep each target isolated in its own project folder.
- Reuse chain-specific helpers without mixing target-specific addresses and PoCs.
- Support multiple PoCs per target as the research deepens.
- Leave room for non-EVM ecosystems such as Solana, Aptos, and Algorand.

## Layout

```text
web3-hack-analysis-template/
├── chains/
│   ├── evm/
│   │   ├── template/
│   │   ├── belong/
│   │   ├── erc4626-inflation-attack/
│   │   └── ups/
│   ├── solana/
│   ├── aptos/
│   └── algorand/
```

## EVM Conventions

- Put one target under `chains/evm/<slug>/`.
- Keep target contracts in `src/target/` when they are original to the project.
- Put reusable interfaces in `src/interfaces/`.
- Put shared chain helpers in `src/shared/`.
- Use `test/helpers/` for fork setup and fixtures.
- Use `test/poc/NN_<Goal>.t.sol` for discrete exploit or validation steps.
- Store chain addresses and fork metadata in `config/`.

## Current Starters

- `chains/evm/template/`: base Foundry starter for a new EVM incident.
- `chains/evm/belong/`: empty starter for the next target.
- `chains/evm/ups/`: seeded from the existing UtopiaSphere analysis.
- `chains/evm/erc4626-inflation-attack/`: the ERC-4626 inflation attack, three defences, and mock replications of the Yearn, Thetanuts and Lazy Summer incident classes. No fork needed.

## Non-EVM Roadmap

- `chains/solana/`: transaction replay, account snapshots, and program-focused PoCs.
- `chains/aptos/`: Move module review, transaction reproduction, and state inspection.
- `chains/algorand/`: TEAL or AVM analysis, grouped transaction replay, and local state capture.

## Suggested Workflow

1. Duplicate `chains/evm/template/` into `chains/evm/<slug>/`.
2. Rename the starter contract and tests to match the incident.
3. Fill `config/addresses.json` and `config/fork.json`.
4. Add `01_ReproduceState`, `02_ExploitPath`, and `03_ImpactValidation` PoCs.
5. Write the target narrative in that project's `README.md`.

## Notes

- This scaffold lives inside the current workspace, and the canonical EVM case folders now live under `chains/evm/`.
- If you want, the next step can be promoting this folder into its own dedicated repository named `web3-hack-analysis-template`.
