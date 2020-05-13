defmodule VintageNet.ActivityMonitor.ClassifierTest do
  use ExUnit.Case

  alias VintageNet.ActivityMonitor.{Classifier, SocketInfo}

  doctest Classifier

  test "classifying IPv4 addresses" do
    addresses = [
      {"eth0",
       [
         %{
           address: {192, 168, 99, 37},
           family: :inet,
           netmask: {255, 255, 255, 0},
           prefix_length: 24,
           scope: :universe
         }
       ]}
    ]

    socket_info = %SocketInfo{
      local_address: {{192, 168, 99, 37}, 58279},
      foreign_address: {{192, 168, 99, 1}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :lan}

    socket_info = %SocketInfo{
      local_address: {{192, 168, 99, 37}, 58279},
      foreign_address: {{18, 208, 87, 62}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :internet}

    socket_info = %SocketInfo{
      local_address: {{192, 168, 99, 37}, 58279},
      foreign_address: {{192, 168, 99, 37}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :local}

    socket_info = %SocketInfo{
      local_address: {{10, 1, 1, 1}, 58279},
      foreign_address: {{10, 1, 1, 2}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:error, :unknown}
  end

  test "classifying with many addresses" do
    addresses = [
      {"lo",
       [
         %{
           address: {0, 0, 0, 0, 0, 0, 0, 1},
           family: :inet6,
           netmask: {65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535},
           prefix_length: 128,
           scope: :host
         },
         %{
           address: {127, 0, 0, 1},
           family: :inet,
           netmask: {255, 0, 0, 0},
           prefix_length: 8,
           scope: :host
         }
       ]},
      {"wlan0",
       [
         %{
           address: {192, 168, 99, 37},
           family: :inet,
           netmask: {255, 255, 255, 0},
           prefix_length: 24,
           scope: :universe
         },
         %{
           address: {65152, 0, 0, 0, 51771, 13823, 65226, 24336},
           family: :inet6,
           netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
           prefix_length: 64,
           scope: :link
         }
       ]},
      {"eth0",
       [
         %{
           address: {10, 0, 0, 5},
           family: :inet,
           netmask: {255, 0, 0, 0},
           prefix_length: 8,
           scope: :universe
         },
         %{
           address: {65152, 0, 0, 0, 51770, 13823, 65226, 24336},
           family: :inet6,
           netmask: {65535, 65535, 65535, 65535, 0, 0, 0, 0},
           prefix_length: 64,
           scope: :link
         }
       ]}
    ]

    socket_info = %SocketInfo{
      local_address: {{192, 168, 99, 37}, 58279},
      foreign_address: {{192, 168, 99, 1}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "wlan0", :lan}

    socket_info = %SocketInfo{
      local_address: {{10, 0, 0, 5}, 58279},
      foreign_address: {{10, 1, 0, 1}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :lan}

    socket_info = %SocketInfo{
      local_address: {{10, 0, 0, 5}, 58279},
      foreign_address: {{192, 168, 99, 37}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :internet}

    socket_info = %SocketInfo{
      local_address: {{127, 0, 0, 1}, 58279},
      foreign_address: {{127, 0, 0, 1}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "lo", :local}

    socket_info = %SocketInfo{
      local_address: {{65152, 0, 0, 0, 51770, 13823, 65226, 24336}, 58279},
      foreign_address: {{65152, 0, 0, 0, 51770, 0, 0, 1}, 443}
    }

    assert Classifier.classify(socket_info, addresses) == {:ok, "eth0", :lan}
  end
end
