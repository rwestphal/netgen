module Netgen
  class PluginEthernet < Plugin
    def name
      'ethernet'
    end

    def link_init(node, link_name, link_attributes)
      mac = link_attributes['mac']
      return unless mac
      node.spawn("ip link set #{link_name} address #{mac}")
    end
  end
end
