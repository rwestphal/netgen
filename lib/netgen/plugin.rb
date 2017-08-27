module Netgen
  class Plugin
    attr_reader :cfg

    class << self
      def inherited(subclass)
        Netgen.plugins.push(subclass.new)
      end
    end

    # Plugin's name.
    def name; end

    # Plugin's configuration options.
    def config_options
      {}
    end

    # Plugin's default configuration.
    def default_config
      {}
    end

    # Parse plugin's configuration section.
    def parse_config(config)
      @cfg = default_config
      return unless config
      config.each do |name, value|
        Config.validate(name, value, config_options)
        @cfg[name] = value
      end
    end

    # Called after a topology is created.
    def topology_init(topology)
      @attributes = Hash(topology[name])
    end

    # Called when the topology is being started.
    def topology_start; end

    # Called before a topology is deleted.
    def topology_exit; end

    # Called after a node is created.
    def node_init(node); end

    # Called when the node is being started.
    def node_start(node); end

    # Called before a node is deleted.
    def node_exit(node); end

    # Called after a link is created.
    def link_init(node, link_name, link_attributes); end

    # Called before a link is deleted.
    def link_exit(node, link_name, link_attributes); end

    # Parse plugin's autogen section of the topology file.
    def autogen_parse(parameters); end

    # Called when a node is generated.
    def autogen_node(type, node_name, node, node_index); end

    # Called when a link is generated.
    def autogen_link(node, name, local_attr, remote_attr); end

    # Called when a loopback interface is generated.
    def autogen_loopback(node, node_index, name, attr); end

    # Called when a stub link is generated.
    def autogen_stub(node, node_index, stub_index, name, attr); end
  end
end
