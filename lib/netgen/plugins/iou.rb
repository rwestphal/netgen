require 'socket'

module Netgen
  class PluginIou < Plugin
    def name
      'iou'
    end

    def config_options
      {
        'dir' => String,
        'images' => Hash
      }
    end

    def default_config
      {
        'dir' => "#{Config::NETGEN_RUNSTATEDIR}/iou",
        'images' => {}
      }
    end

    def topology_init(topology)
      super
      FileUtils.rm_rf(@cfg['dir'])
    end

    def node_init(node)
      return unless node.attributes['iou']
      FileUtils.mkdir_p(node_path(node))
      node.mount("/tmp/netio0")
    end

    def node_start(node)
      return unless node.attributes['iou']
      Netgen.log_info('starting iou', node: node, plugin: self)
      create_netmap_file(node)
      create_config_file(node)

      image_name = node.attributes.dig('iou', 'image')
      raise ArgumentError, "unspecified iou image" unless image_name
      image = @cfg['images'][image_name]
      raise ArgumentError, "image #{image_name} is not configured" unless image

      node.ns.switch_net_namespace do
        node.spawn("NETIO_NETMAP=#{netmap_path(node)} wrapper.bin -m #{image['file']} -p 2000 -- -e 16 -s 0 -c #{config_path(node)} #{node.index + 1} &",
                   options: {}, mnt: false, pid: false, net: false)
        node.attributes['links'].keys.each_with_index do |link, index|
          node.spawn("ioulive86 -n #{netmap_path(node)} -i #{link} #{1000 + index} &",
                     options: {}, mnt: false, pid: false, net: false)
        end
      end
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

    def node_path(node)
      "#{@cfg['dir']}/#{node.name}"
    end

    def config_path(node)
      "#{node_path(node)}/config.txt"
    end

    def netmap_path(node)
      "#{node_path(node)}/NETMAP"
    end

    def create_config_file(node)
      config = @attributes.dig('base-config') || ''
      config += node.attributes.dig('iou', 'config') || ''
      config_replace_variables(config, node.name)
      File.open(config_path(node), 'w') { |file| file.write(config) }
    end

    def config_replace_variables(config, node_name)
      config.gsub!('%(node)', node_name)
    end

    def create_netmap_file(node)
      hostname = `hostname`.rstrip
      content = ''
      node.attributes['links'].keys.each_with_index do |link, index|
        content += "#{node.index + 1}:0/#{index}@#{hostname} #{1000 + index}:0/0@#{hostname}\n"
      end
      File.open(netmap_path(node), 'w') { |file| file.write(content) }
    end
  end
end
