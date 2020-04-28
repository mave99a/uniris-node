use Mix.Config

config :uniris_core, UnirisCore.Crypto,
  supported_curves: [
    :ed25519,
    :secp256r1,
    :secp256k1
  ],
  supported_hashes: [
    :sha256,
    :sha512,
    :sha3_256,
    :sha3_512,
    :blake2b
  ],
  default_curve: :ed25519,
  default_hash: :sha256,
  seed: System.get_env("UNIRIS_CRYPTO_SEED", :crypto.strong_rand_bytes(32)),
  keystore: UnirisCore.Crypto.SoftwareKeystore

config :uniris_core, UnirisCore.P2P,
  port: System.get_env("UNIRIS_P2P_PORT", "3002") |> String.to_integer(),
  node_client: UnirisCore.P2P.NodeTCPClient

config :uniris_core, UnirisCore.Beacon, slot_interval: 5_000

config :uniris_core, UnirisCore.SharedSecrets.NodeRenewal,
  interval: 15_000,
  trigger_interval: 8_000,
  enabled: true

config :uniris_core, UnirisCore.SharedSecrets.TransactionLoader, enabled: true

config :uniris_core, UnirisCore.SelfRepair,
  enabled: true,
  repair_interval: 6_000,
  network_startup_date: DateTime.from_naive!(~N[2020-04-22 00:00:00], "Etc/UTC")

config :uniris_core, UnirisCore.Storage, backend: UnirisCore.Storage.FileBackend

config :uniris_core, UnirisCore.Bootstrap,
  ip_lookup_provider: UnirisCore.Bootstrap.IPLookup.LocalImpl,
  seeds_file: "priv/p2p/seeds",
  interface: "lo",
  enabled: true