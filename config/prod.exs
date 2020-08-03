use Mix.Config

# Do not print debug messages in production
config :logger, level: :info

# TODO: specify the crypto implementation using hardware when developed
config :uniris, Uniris.Crypto, keystore: Uniris.Crypto.SoftwareKeystore

config :uniris, Uniris.Storage, backend: Uniris.Storage.CassandraBackend

config :uniris, Uniris.Storage.CassandraBackend, nodes: ["127.0.0.1:9042"]
config :uniris, Uniris.Storage.FileBackend, root_dir: "priv/storage"

config :uniris, Uniris.Bootstrap, ip_lookup_provider: Uniris.Bootstrap.IPLookup.IPFYImpl

config :uniris, Uniris.Bootstrap.NetworkInit,
  # TODO: provide the true addresses for the genesis UCO distribution
  genesis_pools: [
    funding: [
      public_key: "002E354A95241E867C836E8BBBBF6F9BF2450860BA28B1CF24B734EF67FF49169E",
      amount: 3.82e9
    ],
    deliverable: [
      public_key: "00AD439F0CD4048576D4AFB812DCB1815C57EFC303BFF03696436B157C69547128",
      amount: 2.36e9
    ],
    enhancement: [
      public_key: "008C9309535A3853379D6367F67AB93E3DAF5BFAA41C68BD7C3C1F00AA8D5822FD",
      amount: 9.0e8
    ],
    team: [
      public_key: "00B1F862FF9E534DAC6A0AD32528E08F7BB0F3DD0DCB253B119900F4CE447C5CC4",
      amount: 5.6e8
    ],
    exchange: [
      public_key: "004CD06F40D2F75DA02B29D559A3CBD5E07580B1E65163A4F3256CDC8781B280E3",
      amount: 3.4e8
    ],
    marketing: [
      public_key: "00783510644E885FFAC82FE22FB3F33C5B0936B79B7A3D3A78D5D612341A0B3B9A",
      amount: 3.4e8
    ],
    foundation: [
      public_key: "00CD534224DE5AE2584163D69A8A99F36E6FAE506373B619736B511A58B804E311",
      amount: 2.2e8
    ]
  ]

config :uniris, Uniris.BeaconSlotTimer,
  interval: 600_000,
  trigger_offset: 2_000

config :uniris, Uniris.SharedSecrets.NodeRenewal,
  interval: 86_400_000,
  trigger_offset: 10_000

config :uniris, Uniris.SelfRepair,
  interval: 86_400_000,
  last_sync_file: "priv/p2p/last_sync",
  # TODO: specify the real network startup date
  network_startup_date: %DateTime{
    year: DateTime.utc_now().year,
    month: DateTime.utc_now().month,
    day: DateTime.utc_now().day,
    hour: 0,
    minute: 0,
    second: 0,
    microsecond: {0, 0},
    utc_offset: 0,
    std_offset: 0,
    time_zone: "Etc/UTC",
    zone_abbr: "UTC"
  }

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :uniris, UnirisWeb.Endpoint,
  http: [:inet6, port: 80],
  url: [host: "*", port: 443],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  root: ".",
  version: Application.spec(:phoenix_app, :vsn),
  check_origin: false,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("UNIRIS_WEB_SSL_KEY_PATH"),
    certfile: System.get_env("UNIRIS_WEB_SSL_CERT_PATH"),
    transport_options: [socket_opts: [:inet6]]
  ],
  force_ssl: [hsts: true]
