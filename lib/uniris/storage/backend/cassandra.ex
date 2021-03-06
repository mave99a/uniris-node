defmodule Uniris.Storage.CassandraBackend do
  @moduledoc false

  @insert_transaction_stmt """
  INSERT INTO uniris.transactions(
      address,
      type,
      timestamp,
      data,
      previous_public_key,
      previous_signature,
      origin_signature,
      validation_stamp,
      cross_validation_stamps)
    VALUES(
      :address,
      :type,
      :timestamp,
      :data,
      :previous_public_key,
      :previous_signature,
      :origin_signature,
      :validation_stamp,
      :cross_validation_stamps
    )
  """

  @insert_transaction_chain_stmt """
  INSERT INTO uniris.transaction_chains(
      chain_address,
      fork,
      size,
      transaction_address,
      timestamp)
    VALUES(
      :chain_address,
      :fork,
      :size,
      :transaction_address,
      :timestamp)
  """

  alias Uniris.Transaction
  alias Uniris.Transaction.CrossValidationStamp
  alias Uniris.Transaction.ValidationStamp
  alias Uniris.Transaction.ValidationStamp.LedgerOperations
  alias Uniris.Transaction.ValidationStamp.LedgerOperations.NodeMovement
  alias Uniris.Transaction.ValidationStamp.LedgerOperations.TransactionMovement
  alias Uniris.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  alias Uniris.TransactionData
  alias Uniris.TransactionData.Keys
  alias Uniris.TransactionData.Ledger
  alias Uniris.TransactionData.Ledger.Transfer
  alias Uniris.TransactionData.UCOLedger

  defdelegate child_spec(opts), to: __MODULE__.Supervisor

  @behaviour Uniris.Storage.BackendImpl

  @impl true
  def list_transactions do
    Xandra.stream_pages!(:xandra_conn, "SELECT * FROM uniris.transactions", _params = [])
    |> Stream.flat_map(& &1)
    |> Stream.map(&format_result_to_transaction/1)
  end

  @impl true
  def list_transaction_chains_info do
    Xandra.execute!(:xandra_conn, """
    SELECT size, chain_address as address
    FROM uniris.transaction_chains
    PER PARTITION LIMIT 1
    """)
    |> Enum.map(fn %{"address" => address, "size" => size} ->
      {address, size}
    end)
  end

  @impl true
  def get_transaction(address) do
    prepared = Xandra.prepare!(:xandra_conn, "SELECT * FROM uniris.transactions WHERE address=?")

    Xandra.execute!(:xandra_conn, prepared, [address |> Base.encode16()])
    |> Enum.to_list()
    |> case do
      [] ->
        {:error, :transaction_not_exists}

      [tx] ->
        {:ok, format_result_to_transaction(tx)}
    end
  end

  @impl true
  def get_transaction_chain(address) do
    prepared =
      Xandra.prepare!(:xandra_conn, """
        SELECT transaction_address
        FROM uniris.transaction_chains
        WHERE address=? and fork="main"
      """)

    Xandra.stream_pages!(:xandra_conn, prepared, %{"address" => Base.encode16(address)})
    |> Stream.flat_map(& &1)
    |> Stream.map(&get_transaction/1)
    |> Stream.map(fn {:ok, tx} -> tx end)
  end

  @impl true
  def write_transaction(tx = %Transaction{}) do
    prepared = Xandra.prepare!(:xandra_conn, @insert_transaction_stmt)
    {:ok, _} = Xandra.execute(:xandra_conn, prepared, transaction_write_parameters(tx))
    :ok
  end

  @impl true
  def write_transaction_chain(chain = [%Transaction{address: chain_address} | _]) do
    transaction_prepared = Xandra.prepare!(:xandra_conn, @insert_transaction_stmt)
    chain_prepared = Xandra.prepare!(:xandra_conn, @insert_transaction_chain_stmt)

    chain_size = length(chain)

    Task.async_stream(chain, fn tx ->
      {:ok, _} =
        Xandra.execute(:xandra_conn, transaction_prepared, transaction_write_parameters(tx))

      {:ok, _} =
        Xandra.execute(
          :xandra_conn,
          chain_prepared,
          transaction_chain_write_parameters(chain_address, tx, chain_size)
        )
    end)
    |> Stream.run()
  end

  defp transaction_write_parameters(tx = %Transaction{}) do
    %{
      "address" => tx.address |> Base.encode16(),
      "type" => Atom.to_string(tx.type),
      "timestamp" => tx.timestamp,
      "data" => %{
        "content" => tx.data.content,
        "code" => tx.data.code,
        "keys" => %{
          "authorized_keys" =>
            tx.data.keys.authorized_keys
            |> Enum.map(fn {k, v} ->
              {Base.encode16(k), Base.encode16(v)}
            end)
            |> Enum.into(%{}),
          "secret" => tx.data.keys.secret |> Base.encode16()
        },
        "ledger" => %{
          "uco" => %{
            "transfers" =>
              Enum.map(tx.data.ledger.uco.transfers, fn %{to: to, amount: amount} ->
                %{
                  "recipient" => to |> Base.encode16(),
                  "amount" => amount
                }
              end)
          }
        },
        "recipients" => Enum.map(tx.data.recipients, &Base.encode16/1)
      },
      "previous_public_key" => tx.previous_public_key |> Base.encode16(),
      "previous_signature" => tx.previous_signature |> Base.encode16(),
      "origin_signature" => tx.origin_signature |> Base.encode16(),
      "validation_stamp" => %{
        "proof_of_work" => tx.validation_stamp.proof_of_work |> Base.encode16(),
        "proof_of_integrity" => tx.validation_stamp.proof_of_integrity |> Base.encode16(),
        "ledger_operations" => %{
          "fee" => tx.validation_stamp.ledger_operations.fee,
          "transaction_movements" =>
            Enum.map(
              tx.validation_stamp.ledger_operations.transaction_movements,
              fn %TransactionMovement{
                   to: to,
                   amount: amount
                 } ->
                %{"recipient" => to |> Base.encode16(), "amount" => amount}
              end
            ),
          "node_movements" =>
            Enum.map(tx.validation_stamp.ledger_operations.node_movements, fn %NodeMovement{
                                                                                to: to,
                                                                                amount: amount
                                                                              } ->
              %{"recipient" => to |> Base.encode16(), "amount" => amount}
            end),
          "unspent_outputs" =>
            Enum.map(
              tx.validation_stamp.ledger_operations.unspent_outputs,
              fn %UnspentOutput{from: from, amount: amount} ->
                %{"origin" => from |> Base.encode16(), "amount" => amount}
              end
            )
        },
        "signature" => tx.validation_stamp.signature |> Base.encode16()
      },
      "cross_validation_stamps" =>
        Enum.map(tx.cross_validation_stamps, fn %CrossValidationStamp{
                                                  signature: signature,
                                                  node_public_key: node_public_key
                                                } ->
          %{
            "node" => node_public_key |> Base.encode16(),
            "signature" => signature |> Base.encode16()
          }
        end)
    }
  end

  defp transaction_chain_write_parameters(chain_address, tx = %Transaction{}, chain_size) do
    %{
      "chain_address" => Base.encode16(chain_address),
      "transaction_address" => Base.encode16(tx.address),
      "size" => chain_size,
      "timestamp" => tx.timestamp,
      "fork" => "main"
    }
  end

  def format_result_to_transaction(%{
        "address" => address,
        "type" => type,
        "timestamp" => timestamp,
        "data" => %{
          "content" => content,
          "code" => code,
          "keys" => %{
            "authorized_keys" => authorized_keys,
            "secret" => secret
          },
          "ledger" => %{
            "uco" => %{
              "transfers" => transfers
            }
          },
          "recipients" => recipients
        },
        "previous_public_key" => previous_public_key,
        "previous_signature" => previous_signature,
        "origin_signature" => origin_signature,
        "validation_stamp" => %{
          "proof_of_work" => pow,
          "proof_of_integrity" => poi,
          "ledger_operations" => %{
            "fee" => fee,
            "transaction_movements" => transaction_movements,
            "node_movements" => node_movements,
            "unspent_outputs" => utxo
          },
          "signature" => signature
        },
        "cross_validation_stamps" => cross_validation_stamps
      }) do
    %Transaction{
      address: address |> Base.decode16!(),
      type: String.to_atom(type),
      data: %TransactionData{
        content: content,
        code: code,
        keys: %Keys{
          authorized_keys:
            Enum.map(authorized_keys, fn {k, v} ->
              {Base.decode16!(k), Base.decode16!(v)}
            end)
            |> Enum.into(%{}),
          secret: secret |> Base.decode16!()
        },
        ledger: %Ledger{
          uco: %UCOLedger{
            transfers:
              Enum.map(transfers, fn %{"recipient" => to, "amount" => amount} ->
                %Transfer{
                  amount: amount,
                  to: to |> Base.decode16!()
                }
              end)
          }
        },
        recipients: Enum.map(recipients, &Base.decode16!/1)
      },
      timestamp: timestamp,
      previous_public_key: previous_public_key |> Base.decode16!(),
      previous_signature: previous_signature |> Base.decode16!(),
      origin_signature: origin_signature |> Base.decode16!(),
      validation_stamp: %ValidationStamp{
        proof_of_work: pow |> Base.decode16!(),
        proof_of_integrity: poi |> Base.decode16!(),
        ledger_operations: %LedgerOperations{
          fee: fee,
          transaction_movements:
            Enum.map(transaction_movements, fn %{"recipient" => to, "amount" => amount} ->
              %TransactionMovement{to: to |> Base.decode16!(), amount: amount}
            end),
          node_movements:
            Enum.map(node_movements, fn %{"recipient" => to, "amount" => amount} ->
              %NodeMovement{to: to |> Base.decode16!(), amount: amount}
            end),
          unspent_outputs:
            Enum.map(utxo, fn %{"origin" => from, "amount" => amount} ->
              %UnspentOutput{
                from: from |> Base.decode16!(),
                amount: amount
              }
            end)
        },
        signature: signature |> Base.decode16!()
      },
      cross_validation_stamps:
        Enum.map(cross_validation_stamps, fn %{
                                               "node" => node,
                                               "signature" => signature
                                             } ->
          %CrossValidationStamp{
            signature: signature |> Base.decode16!(),
            node_public_key: node |> Base.decode16!(),
            inconsistencies: []
          }
        end)
    }
  end
end
