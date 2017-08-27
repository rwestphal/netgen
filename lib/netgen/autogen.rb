module Netgen
  module Autogen
    # Dynamically generated node
    class Node
      attr_reader :index
      attr_reader :name
      attr_reader :connections

      @global_index = -1
      def self.next_index
        @global_index += 1
      end

      def initialize(name)
        @index = Node.next_index
        @name = name
        @link_index = 0
        @connections = {}
      end

      # Connect to another node using N links (Layout.parallel_links).
      def connect(peer)
        return if @connections[peer]
        @connections[peer] = []
        peer.connections[self] = []

        Layout.parallel_links.times do
          local = add_link
          remote = peer.add_link
          @connections[peer].push([local, remote])
          peer.connections[self].push([remote, local])
        end
      end

      # Add new link
      def add_link
        name = "#{@name}-eth#{@link_index}"
        @link_index += 1
        name
      end

      # Output node to format understandable by the Netgen main engine
      def output
        output = {}

        Netgen.plugins.each do |plugin|
          plugin.autogen_node(self.class, self.name, output, @index)
        end
        output['links'] = {}

        @connections.each do |peer|
          peer_name = peer[0].name
          peer[1].each do |connection|
            local, remote = connection
            output['links'][local] = {}
            output['links'][local]['peer'] = [peer_name, remote]
          end
        end
        output
      end
    end

    # Dynamically generated router
    class Router < Node
      attr_reader :loopback
      attr_reader :stubs

      def initialize(name)
        super(name)
        @loopback = "#{@name}-lo1"
        add_stubs
      end

      # Add N (Layout.stub_networks) stub links.
      def add_stubs
        @stub_index = 0
        @stubs = []
        Layout.stub_networks.times do
          @stubs.push("#{@name}-stub#{@stub_index}")
          @stub_index += 1
        end
      end

      # Append loopback and stubs to the main output
      def output
        output = super
        output_loopback(output)
        output_stubs(output)
        output
      end

      def output_loopback(output)
        links = output['links']
        links[@loopback] = {}
        Netgen.plugins.each do |plugin|
          plugin.autogen_loopback(output, @index, @loopback, links[@loopback])
        end
      end

      def output_stubs(output)
        links = output['links']
        @stubs.each_with_index do |stub, stub_index|
          links[stub] = {}
          Netgen.plugins.each do |plugin|
            plugin.autogen_stub(output, @index, stub_index, stub, links[stub])
          end
        end
      end
    end

    # Dynamically generated switch
    class Switch < Node
    end

    # Layout base class
    class Layout
      class << self
        attr_accessor :parallel_links
        attr_accessor :stub_networks
      end

      def initialize(description)
        @description = description
        @routers = []
        @switches = []
      end

      # Parse the 'autogen' section of the topology file
      def parse
        Layout.parallel_links = @description['parallel-links'] || 1
        Layout.stub_networks = @description['stub-networks'] || 0
      end

      # Output generated topology to format understandable by the Netgen
      # main engine
      def output
        output = {}
        output['routers'] = {}
        output['switches'] = {}
        @routers.each do |router|
          output['routers'][router.name] = router.output
        end
        @switches.each do |switch|
          output['switches'][switch.name] = switch.output
        end
        output_links(output)
        output
      end

      # TODO: need to move this to the output method of the Node class and
      # unify routers and switches under the same section in the topology
      # files.
      def output_links(output)
        output['routers'].values.each do |router|
          router['links'].each do |link|
            next unless link[1]['peer']
            local_name = link[0]
            local_attr = link[1]
            peer_name = local_attr['peer'][0]
            peer_link = local_attr['peer'][1]
            remote_attr = output['routers'][peer_name]['links'][peer_link]
            Netgen.plugins.each do |plugin|
              plugin.autogen_link(router, local_name, local_attr, remote_attr)
            end
          end
        end
      end
    end

    # Line topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: line
    #     size: 5
    #
    # Generated topology:
    #   rt0---rt1---rt2---rt3---rt4
    #
    class LayoutLine < Layout
      def parse
        super
        @size = @description['size']
        raise ArgumentError, 'Unspecified size' unless @size
        raise ArgumentError, 'Invalid size' unless @size > 0
      end

      def generate
        generate_routers
        generate_links
      end

      def generate_routers
        @size.times do |i|
          @routers[i] = Router.new("rt#{i}")
        end
      end

      def generate_links
        @size.times do |i|
          @routers[i].connect(@routers[i - 1]) if i > 0
          @routers[i].connect(@routers[i + 1]) if i < @size - 1
        end
      end
    end

    # Ring topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: ring
    #     size: 5
    #
    # Generated topology:
    #   rt0---rt1---rt2---rt3---rt4
    #    |                       |
    #    +-----------------------+
    #
    class LayoutRing < Layout
      def parse
        super
        @size = @description['size']
        raise ArgumentError, 'Unspecified size' unless @size
        raise ArgumentError, 'Invalid size' unless @size > 0
      end

      def generate
        generate_routers
        generate_links
      end

      def generate_routers
        @size.times do |i|
          @routers[i] = Router.new("rt#{i}")
        end
      end

      def generate_links
        @size.times do |i|
          left = (i == 0 ? @size - 1 : i - 1)
          right = (i == @size - 1 ? 0 : i + 1)
          @routers[i].connect(@routers[left])
          @routers[i].connect(@routers[right])
        end
      end
    end

    # Grid topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: grid
    #     width: 3
    #     height: 3
    #
    # Generated topology:
    #   rt0x0---rt1x0---rt2x0
    #     +       +       +
    #     |       |       |
    #     +       +       +
    #   rt0x1---rt1x1---rt2x1
    #     +       +       +
    #     |       |       |
    #     +       +       +
    #   rt0x2---rt1x2---rt2x2
    #
    class LayoutGrid < Layout
      def parse
        super
        @width = @description['width']
        raise ArgumentError, 'Unspecified width' unless @width
        raise ArgumentError, 'Invalid width' unless @width > 0
        @height = @description['height']
        raise ArgumentError, 'Unspecified height' unless @height
        raise ArgumentError, 'Invalid height' unless @height > 0
      end

      def generate
        generate_routers
        generate_links
      end

      def generate_routers
        @width.times do |x|
          @height.times do |y|
            @routers[index(x, y)] = Router.new("rt#{x}x#{y}")
          end
        end
      end

      def generate_links
        @width.times do |x|
          @height.times do |y|
            router = @routers[index(x, y)]
            router.connect(@routers[index(x - 1, y)]) if x > 0
            router.connect(@routers[index(x + 1, y)]) if x < @width - 1
            router.connect(@routers[index(x, y - 1)]) if y > 0
            router.connect(@routers[index(x, y + 1)]) if y < @height - 1
          end
        end
      end

      def index(x, y)
        y * @width + x
      end
    end

    # Tree topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: tree
    #     height: 3
    #     degree: 2
    #
    # Generated topology:
    #                 rt0
    #                  +
    #                  |
    #          +-------+-------+
    #          |               |
    #          +               +
    #         rt1             rt2
    #          +               +
    #          |               |
    #      +---+---+       +---+---+
    #      |       |       |       |
    #      +       +       +       +
    #     rt3     rt4     rt5     rt6
    #
    class LayoutTree < Layout
      def parse
        super
        @height = @description['height']
        raise ArgumentError, 'Unspecified height' unless @height
        raise ArgumentError, 'Invalid height' unless @height > 0
        @degree = @description['degree']
        raise ArgumentError, 'Unspecified degree' unless @degree
        raise ArgumentError, 'Invalid degree' unless @degree > 0
      end

      # Create tree recursively
      def create_tree(root, height, degree)
        degree.times do |i|
          child = add_router
          child.connect(root)
          create_tree(child, height - 1, degree) if height > 1
        end
      end

      def generate
        @index = 0
        root = add_router
        create_tree(root, @height - 1, @degree)
      end

      def add_router
        router = Router.new("rt#{@index}")
        @routers[@index] = router
        @index += 1
        router
      end
    end

    # Full-mesh topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: full-mesh
    #     size: 4
    #
    # Generated topology:
    #   +------+rt0+------+
    #   |        +        |
    #   |        |        |
    #   +        |        +
    #  rt1+------+------+rt2
    #   +        |        +
    #   |        |        |
    #   |        +        |
    #   +------+rt3+------+
    #
    class LayoutFullMesh < Layout
      def parse
        super
        @size = @description['size']
        raise ArgumentError, 'Unspecified size' unless @size
        raise ArgumentError, 'Invalid size' unless @size > 0
      end

      def generate
        generate_routers
        generate_links
      end

      def generate_routers
        @size.times do |i|
          @routers[i] = Router.new("rt#{i}")
        end
      end

      def generate_links
        @size.times do |i|
          @size.times do |j|
            @routers[i].connect(@routers[j]) if i != j
          end
        end
      end
    end

    # Bus topology layout
    #
    # Example
    #
    # Configuration:
    #   layout:
    #     type: bus
    #     size: 5
    #
    # Generated topology:
    #          rt0
    #           +
    #           |
    #           +
    #  rt1+---+sw1+---+rt2
    #           +
    #           |
    #           +
    #          rt3
    #
    class LayoutBus < Layout
      def parse
        super
        @size = @description['size']
        raise ArgumentError, 'Unspecified size' unless @size
        raise ArgumentError, 'Invalid size' unless @size > 0
      end

      def generate
        generate_bus
        generate_routers
        generate_links
      end

      def generate_bus
        @switches[0] = Switch.new('sw1')
      end

      def generate_routers
        @size.times do |i|
          @routers[i] = Router.new("rt#{i}")
        end
      end

      def generate_links
        @size.times do |i|
          @routers[i].connect(@switches[0])
        end
      end
    end
  end
end
