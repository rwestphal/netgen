module Netgen
  class Switch < Node
    # Create virtual bridge and bring it up.
    def setup
      super
      execute('ip link add name br0 type bridge')
      execute('ip link set dev br0 up')
    end

    # Add all links to the bridge.
    def setup_links(nodes)
      super
      @attributes['links'].keys.each do |name|
        spawn("ip link set #{name} master br0")
      end
    end
  end
end
