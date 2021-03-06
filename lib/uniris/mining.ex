defmodule Uniris.Mining do
  @moduledoc """
  Provide functions to perform steps of the transaction mining delegating the work
  to a mining FSM.

  Every transaction mining follows these steps:
  - Pending transaction verification
  - Validation node election verification
  - Context retreival (previous chain, unspent outputs)
  - Validation stamp and replication tree creation (coordinator)
  - Stamp and replication tree validation (cross validator)
  - Replication (once the atomic commitment is reached)
  """

  alias Uniris.Beacon
  alias Uniris.Bootstrap.NetworkInit
  alias Uniris.Crypto

  alias __MODULE__.Context
  alias __MODULE__.Replication
  alias __MODULE__.Worker
  alias __MODULE__.WorkerSupervisor
  alias Uniris.MiningRegistry

  alias Uniris.P2P
  alias Uniris.P2P.Message.ReplicateTransaction

  alias Uniris.TaskSupervisor

  alias Uniris.Transaction
  alias Uniris.Transaction.CrossValidationStamp
  alias Uniris.Transaction.ValidationStamp
  alias Uniris.Transaction.ValidationStamp.LedgerOperations

  require Logger

  @doc """
  Start mining process for a given transaction.
  """
  @spec start(
          transaction :: Transaction.pending(),
          welcome_node_public_key :: Uniris.Crypto.key(),
          validation_node_public_keys :: list(Uniris.Crypto.key())
        ) :: {:ok, pid()}

  def start(tx = %Transaction{}, _, [_ | []]) do
    Task.start(fn ->
      Logger.info("Mining transaction #{Base.encode16(tx.address)}")

      tx =
        %Transaction{validation_stamp: %ValidationStamp{ledger_operations: ledger_ops}} =
        NetworkInit.self_validation!(tx, Context.fetch_history(%Context{}, tx))

      chain_storage_nodes =
        P2P.list_nodes()
        |> Enum.filter(& &1.available?)
        |> Enum.filter(& &1.ready?)

      beacon_storage_nodes =
        tx.address
        |> Beacon.subset_from_address()
        |> Beacon.get_pool(tx.timestamp)

      io_storage_nodes = LedgerOperations.io_storage_nodes(ledger_ops)

      storage_nodes =
        Enum.uniq_by(
          chain_storage_nodes ++ beacon_storage_nodes ++ io_storage_nodes,
          & &1.last_public_key
        )

      TaskSupervisor
      |> Task.Supervisor.async_stream(
        storage_nodes,
        &P2P.send_message(&1, %ReplicateTransaction{transaction: tx})
      )
      |> Stream.run()
    end)
  end

  def start(tx = %Transaction{}, welcome_node_public_key, validation_node_public_keys) do
    DynamicSupervisor.start_child(WorkerSupervisor, {
      Worker,
      transaction: tx,
      welcome_node_public_key: welcome_node_public_key,
      validation_node_public_keys: validation_node_public_keys,
      node_public_key: Crypto.node_public_key()
    })
  end

  @doc """
  Add a context which has been built by another validation node and provide view of storage and validation nodes.
  """
  @spec add_context(
          address :: binary(),
          validation_node_public_key :: Crypto.key(),
          context :: Context.t()
        ) ::
          :ok
  def add_context(
        tx_address,
        validation_node_public_key,
        context = %Context{}
      ) do
    Worker.add_context(
      get_worker_pid(tx_address),
      validation_node_public_key,
      context
    )
  end

  @doc """
  Cross validate the validation stamp and the replication tree produced by the coordinator

  If no inconsistencies, the validation stamp is stamped by the the node public key.
  Otherwise the inconsistencies will be signed.
  """
  @spec cross_validate(
          address :: binary(),
          ValidateStamp.t(),
          replication_tree :: list(bitstring())
        ) :: :ok
  def cross_validate(tx_address, stamp = %ValidationStamp{}, replication_tree) do
    Worker.cross_validate(get_worker_pid(tx_address), stamp, replication_tree)
  end

  @doc """
  Add a cross validation stamp to the transaction mining process
  """
  @spec add_cross_validation_stamp(
          binary(),
          stamp :: CrossValidationStamp.t()
        ) ::
          :ok
  def add_cross_validation_stamp(
        tx_address,
        stamp = %CrossValidationStamp{}
      ) do
    Worker.add_cross_validation_stamp(get_worker_pid(tx_address), stamp)
  end

  @doc """
  Execute the transaction replication according to the election storage node rules performing
  the necessary checks depending on the storage node role.

  Election algorithms are used to determine if the transaction must be validated as
  - chain storage node
  - unspent output/movement node
  - beacon node

  And the underlaying storage rules
  """
  @spec replicate_transaction(Transaction.t()) :: :ok
  def replicate_transaction(tx = %Transaction{}), do: Replication.run(tx)

  defp get_worker_pid(tx_address, attemps \\ 0) do
    case Registry.lookup(MiningRegistry, tx_address) do
      [{pid, _}] ->
        pid

      _ ->
        if attemps < 5 do
          Process.sleep(100)
          get_worker_pid(tx_address, attemps + 1)
        end
    end
  end
end
