module Netgen
  class PluginTcpdump < Plugin
    def name
      'tcpdump'
    end

    def config_options
      {
        'pcap_dir' => String,
        'whitelist' => Array,
        'blacklist' => Array
      }
    end

    def default_config
      {
        'pcap_dir' => "#{Config::NETGEN_RUNSTATEDIR}/pcaps",
        'whitelist' => [],
        'blacklist' => []
      }
    end

    def node_init(node)
      FileUtils.mkdir_p("#{pcap_dir(node)}")
      FileUtils.rm(Dir.glob("#{pcap_dir(node)}/*.pcap"))
    end

    def link_init(node, link_name, link_attributes)
      # Don't run tcpdump on stub links
      return unless link_attributes['peer']

      # Check whitelist and blacklist
      return unless @cfg['whitelist'].empty? ||
                    @cfg['whitelist'].include?(node.name)
      return if @cfg['blacklist'].include?(node.name)

      path = "#{pcap_dir(node)}/#{link_name}.pcap"
      node.spawn("tcpdump -i #{link_name} -U -w #{path}",
                 options: { out: '/dev/null', err: '/dev/null' })
    end

    def pcap_dir(node)
      "#{@cfg['pcap_dir']}/#{node.name}"
    end
  end
end
