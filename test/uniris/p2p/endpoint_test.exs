defmodule Uniris.P2P.EndpointTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  @tcp_options [:binary, packet: 4, active: false]

  alias Uniris.P2P.Endpoint

  alias Uniris.P2P.Message
  alias Uniris.P2P.Message.BootstrappingNodes
  alias Uniris.P2P.Message.GetBootstrappingNodes

  setup do
    port = 10_000
    {:ok, _} = Endpoint.start_link(port: port)
    {:ok, %{port: port}}
  end

  test "send message node should retrieve data", %{port: port} do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, @tcp_options)
    :ok = :gen_tcp.send(socket, Message.encode(%GetBootstrappingNodes{patch: "AAA"}))

    {:ok, data} = :gen_tcp.recv(socket, 0)
    assert %BootstrappingNodes{} = Message.decode(data)
    :gen_tcp.close(socket)
  end
end
