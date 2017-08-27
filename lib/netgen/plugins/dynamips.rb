require 'socket'

module Netgen
  class PluginDynamips < Plugin
    def name
      'dynamips'
    end

    def config_options
      {
        'dir' => String,
        'images' => Hash
      }
    end

    def default_config
      {
        'dir' => "#{Config::NETGEN_RUNSTATEDIR}/dynamips",
        'images' => {}
      }
    end

    def topology_init(topology)
      super
      FileUtils.rm_rf(@cfg['dir'])
    end

    def node_init(node)
      return unless node.attributes['dynamips']
      FileUtils.mkdir_p(node_path(node))
    end

    def node_start(node)
      return unless node.attributes['dynamips']
      Netgen.log_info('starting dynamips', node: node, plugin: self)
      node.spawn('dynamips -H 7200',
                 options: { out: '/dev/null', err: '/dev/null' })
      create_config_file(node)
      Netgen.log_info('connecting to hypervisor', node: node, plugin: self)
      connect(node)
    rescue ArgumentError => e
      Netgen.log_err("error parsing topology: #{e}", plugin: self, node: node)
      exit(1)
    end

    # Disable tx checksum offloading
    # TODO: find out why this is necessary
    def link_init(node, link_name, _link_attributes)
      return if @attributes.empty?
      node.spawn("ethtool -K #{link_name} tx off",
                 options: { out: '/dev/null', err: '/dev/null' })
    end

    def connect(node)
      node.ns.switch_net_namespace do
        sock = TCPSocket.new('127.0.0.1', 7200)
        configure(node, sock)
        sock.close
      end
    rescue Errno::ECONNREFUSED
      sleep 0.1
      retry
    end

    def configure(node, sock)
      Netgen.log_info('configuring', node: node, plugin: self)
      image_name = node.attributes.dig('dynamips', 'image')
      raise ArgumentError, "unspecified dynamips image" unless image_name
      image = @cfg['images'][image_name]
      raise ArgumentError, "image #{image_name} is not configured" unless image

      # initialization
      command(node, sock, 'hypervisor version')
      command(node, sock, 'hypervisor reset')
      command(node, sock, "hypervisor working_dir \"#{node_path(node)}\"")

      # set image parameters according to the configuation
      image['parameters'].each_line do |line|
        command(node, sock, line)
      end

      # set the console listening port and configuration file
      command(node, sock, 'vm set_con_tcp_port rt 2000')
      command(node, sock, "vm set_config rt \"#{config_path(node)}\"")

      # setup interfaces
      node.attributes['links'].keys.each_with_index do |link, index|
        slot, port = image['interfaces'][index]
        command(node, sock, "nio create_linux_eth #{link} #{link}")
        command(node, sock, "vm slot_add_nio_binding rt #{slot} #{port} #{link}")
      end

      # start the router
      command(node, sock, 'vm start rt')
    end

    def command(node, sock, command)
      Netgen.log_debug("sending: #{command}", node: node, plugin: self)
      sock.puts(command)
      Netgen.log_debug("received: #{sock.gets}", node: node, plugin: self)
    end

    def node_path(node)
      "#{@cfg['dir']}/#{node.name}"
    end

    def config_path(node)
      "#{node_path(node)}/config.txt"
    end

    def create_config_file(node)
      config = @attributes.dig('base-config') || ''
      config += node.attributes.dig('dynamips', 'config') || ''
      config_replace_variables(config, node.name)
      File.open(config_path(node), 'w') { |file| file.write(config) }
    end

    def config_replace_variables(config, node_name)
      config.gsub!('%(node)', node_name)
    end
  end
end
