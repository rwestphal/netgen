module Netgen
  class Router < Node
    # Bring up router's loopback interface.
    def setup
      super
      spawn('ip link set dev lo up')
      spawn('sysctl net.ipv4.tcp_l3mdev_accept=1')
    end
  end
end
