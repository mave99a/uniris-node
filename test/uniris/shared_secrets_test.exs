defmodule Uniris.SharedSecretsTest do
  use UnirisCase, async: false

  alias Uniris.Crypto
  alias Uniris.SharedSecrets

  alias Uniris.Transaction
  alias Uniris.TransactionData

  test "new_node_shared_secrets_transaction/3 should create a new node shared secrets transaction" do
    aes_key = :crypto.strong_rand_bytes(32)

    %Transaction{
      type: :node_shared_secrets,
      data: %TransactionData{
        keys: %{
          authorized_keys: authorized_keys,
          secret: _
        }
      }
    } =
      SharedSecrets.new_node_shared_secrets_transaction(
        [Crypto.node_public_key()],
        "daily_nonce_seed",
        aes_key
      )

    assert Map.has_key?(authorized_keys, Crypto.node_public_key())
  end
end
