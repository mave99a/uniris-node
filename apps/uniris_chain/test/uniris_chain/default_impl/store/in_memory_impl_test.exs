defmodule UnirisChain.DefaultImpl.Store.InMemoryImplTest do
  use ExUnit.Case

  alias UnirisChain.DefaultImpl.Store.InMemoryImpl, as: Store
  alias UnirisChain.Transaction
  alias UnirisCrypto, as: Crypto

  setup do
    Crypto.add_origin_seed("origin_seed")
    :ok
  end

  test "get_transaction/1 should return an error when the transaction does not exists" do
    assert {:error, :transaction_not_exists} =
             Store.get_transaction(:crypto.strong_rand_bytes(32))
  end

  test "get_transaction_chain/1 should return an error when the transaction chain does not exists" do
    assert {:error, :transaction_chain_not_exists} =
             Store.get_transaction_chain(:crypto.strong_rand_bytes(32))
  end

  test "get_unspent_output_transactions/1 should return an error when the utxo does not exists" do
    assert {:error, :unspent_output_transactions_not_exists} =
             Store.get_unspent_output_transactions(:crypto.strong_rand_bytes(32))
  end

  test "store_transaction/1 should persist the transaction in its state and build the lookup" do
    tx = Transaction.from_seed("myseed", :transfer)
    assert :ok = Store.store_transaction(tx)
    assert {:ok, %Transaction{}} = Store.get_transaction(tx.address)
    assert {:ok, [%Transaction{}]} = Store.get_transaction_chain(tx.address)
  end

  test "store_transaction_chain/1 should persist an entire chain in its state and build the lookup" do
    tx = Transaction.from_seed("myseed", :transfer)
    tx2 = Transaction.from_seed("myseed", :transfer)
    assert :ok = Store.store_transaction_chain([tx2, tx])
    assert {:ok, [tx2, tx]} = Store.get_transaction_chain(tx.address)
    assert {:ok, [tx2, tx]} = Store.get_transaction_chain(tx2.address)
    assert {:ok, tx} = Store.get_transaction(tx.address)
  end

  test "get_unspent_output_transactions/1 should return a list of transaction in link to the given address" do
    tx =
      Transaction.from_seed("myseed", :transfer, %Transaction.Data{
        ledger: %{
          uco: %Transaction.Data.Ledger.UCO{
            transfers: [
              %Transaction.Data.Ledger.Transfer{to: "destination_address", amount: 10}
            ]
          }
        }
      })

    :ok = Store.store_transaction(tx)
    {:ok, [_tx]} = Store.get_unspent_output_transactions("destination_address")
  end

  test "get_last_node_shared_secrets_transaction/1 should return the node shared secret transaction" do
    tx = Transaction.from_seed("myseed", :node_shared_secrets)
    :ok = Store.store_transaction(tx)
    {:ok, _tx} = Store.get_last_node_shared_secrets_transaction()
  end
end
