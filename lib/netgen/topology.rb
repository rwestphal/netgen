require 'yaml'

module Netgen
  class Topology
    attr_accessor :nodes

    def initialize(filename)
      @nodes = {}

      topology = YAML.load_file(filename)

      autogen_start(topology) if topology['autogen']

      Netgen.plugins.each do |plugin|
        plugin.topology_init(topology)
      end
      Hash(topology['routers']).each do |name, attributes|
        @nodes[name] = Router.new(name, attributes)
      end
      Hash(topology['switches']).each do |name, attributes|
        @nodes[name] = Switch.new(name, attributes)
      end
    rescue SystemCallError, Psych::SyntaxError, ArgumentError => e
      $stderr.puts e.message
      $stderr.puts e.backtrace
      exit(1)
    end

    # Check if the topology is valid or not.
    def check_consistency
      @nodes.values.each do |node|
        node.check_consistency(@nodes)
      end
    end

    # Setup topology. All nodes must be created before creating the links.
    def setup
      Netgen.log_info("netgen: setting up nodes")
      @nodes.values.each(&:setup)
      Netgen.log_info("netgen: creating links")
      @nodes.values.each do |node|
        node.setup_links(@nodes)
      end
    end

    # Cleanup topology
    def cleanup
      #if Netgen.config.options['clean_exit'] == 'true'
      Netgen.log_info("netgen: cleaning up everything")
      FileUtils.rm(pids_filename)
      Netgen.plugins.each(&:topology_exit)
      @nodes.values.each(&:cleanup)

      # Kill all children
      @nodes.values.each do |node|
        Process.kill(:TERM, node.ns.pid)
      end
      Netgen.log_info("netgen: waiting for children to terminate")
      Process.waitall
    end

    # Start the topology once everything is initialized
    def start
      Netgen.log_info('netgen: starting topology')
      generate_pids_file
      Netgen.plugins.each(&:topology_start)
      @nodes.values.each(&:start)
      Netgen.log_info('netgen: topology started')
    end

    def pids_filename
      "#{Netgen.config.options['netgen_runstatedir']}/pids.yml"
    end

    def generate_pids_file
      pids = {}
      @nodes.each do |name, node|
        pids[name] = node.ns.pid
      end
      File.open(pids_filename, 'w') { |file| file.write(pids.to_yaml) }
    end

    # Generate topology
    def autogen_start(topology)
      description = topology.dig('autogen', 'layout')
      case topology.dig('autogen', 'layout', 'type')
      when 'line'
        autogen = Autogen::LayoutLine.new(description)
      when 'ring'
        autogen = Autogen::LayoutRing.new(description)
      when 'grid'
        autogen = Autogen::LayoutGrid.new(description)
      when 'tree'
        autogen = Autogen::LayoutTree.new(description)
      when 'full-mesh'
        autogen = Autogen::LayoutFullMesh.new(description)
      when 'bus'
        autogen = Autogen::LayoutBus.new(description)
      else
        raise ArgumentError, "Unknown or unspecified layout type"
      end
      autogen.parse

      Netgen.plugins.each do |plugin|
        description = topology.dig('autogen', plugin.name)
        plugin.autogen_parse(description)
      end

      Netgen.log_info('autogen: generating topology')
      autogen.generate
      topology.merge!(autogen.output)
      Netgen.log_info('autogen: done')

      # Save generated topology
      if Netgen.output
        topology.delete('autogen')
        File.open(Netgen.output, 'w') { |file| file.write(topology.to_yaml) }
      end
    end
  end
end
