defmodule UnirisNetwork.P2P.SupervisedConnection.TCPTest do
  use ExUnit.Case

  alias UnirisNetwork.Node
  alias UnirisNetwork.P2P.SupervisedConnection.TCPImpl, as: Connection
  alias UnirisNetwork.P2P.Message

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  test "start_link/3 should establish a connection" do
    {:ok, pub} = UnirisCrypto.generate_random_keypair()
    {:ok, pid} = Connection.start_link(pub, "127.0.0.1", Application.get_env(:uniris_network, :port))
    assert match? {:connected, _}, :sys.get_state(pid)
  end

  test "send_message/2 should send a message and get results" do
    
    {:ok, pub} = UnirisCrypto.generate_random_keypair()
    {:ok, pid} = Connection.start_link(pub, "127.0.0.1", Application.get_env(:uniris_network, :port))

    Connection.send_message(pid, Message.encode {:get_transaction, "@Alice1"})
  end

end
  