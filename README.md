# Uniris

Welcome to the Uniris Node source repository ! This software enables you to build the first transaction chain and next generation of blockchain focused on scalability and human oriented.

Uniris features:
- Fast transaction processing (> 1M tps)
- Lower energy consomption than other blockchain
- Designed with a high level of security (ARCH consensus supporting 90% of maliciousness)
- Adapative cryptographic algorithms (quantum resistant)
- Decentralized Identity and Self Sovereign Identity
- Smart contract platform powered by a built-in interpreter
- Strong scalability with geo secured sharding
- Soft-Real-Time P2P view with supervised networking

## Development

Our codebase aims to reach the guidelines of Elixir projects.
We are focusing on the best quality.

The source code can be brough to change to respect the best quality of reading and regarding best practices.

Current implemented features:
- Adapative cryptography: different elliptic curves and software implementation
- TransactionChain: basic struct and transaction generation
- Smart Contract: interpreter coded with Elixir DSL through Metaprogramming and AST
- Node election: heurisitic validation and storage node selection
- P2P: Inter-node communication, supervised connection to detect the P2P view of nodes in almost real-time
- Transaction mining: ARCH consensus
- Node bootstraping
- Beacon chain: Track new transactions and node readyness
- Self-Repair: Self-healing mechanism allowing to resynchronize missing transactions
- Node shared secrets renewal: Integration of authorized validation nodes using heuristic constraints
- P2P transfers and genesis pools allocation
- Transaction explorer
- Custom Binary protocol leveraging Binary Pattern Matching and BitVectors

## Next features to appear very soon:
- Sampling P2P view on the Beacon chain
- Summary of the Beacon chain
- Smart Contract Standard library functions
- P2P messages encryption
- OnChain Governance & Decentralized Code Source and Hot Release Upgrades

## Installation

Requirements:
- Libsodium: for the ed25519 encryption and decryption.
- OTP 23: generation of ed25519 keypair

Platforms supported:
- Linux
- Mac OS X

Requires Cassandra/ScyllaDB installation to use for the backend storage

## Development

Requires Elixir 1.10

To start first node:
```bash
mix deps.get
UNIRIS_CRYPTO_SEED="node1" iex -S mix phx.server
```

To start a second node
```bash
UNIRIS_CRYPTO_SEED="node2" UNIRIS_P2P_PORT=3005 iex -S mix
```

To clean the environment before, execute the following mix task
```
mix clean_priv_dir
```

## Contribution

Thank you for considering to help out with the source code. 
We welcome contributions from anyone and are grateful for even the smallest of improvement.

Please to follow this workflow:
1. Fork it!
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create new Pull Request


## Licence

AGPL
