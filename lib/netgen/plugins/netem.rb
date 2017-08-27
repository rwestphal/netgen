module Netgen
  class PluginNetem < Plugin
    def name
      'netem'
    end

    def link_init(node, link_name, link_attributes)
      netem = link_attributes['netem']
      return unless netem
      node.spawn("tc qdisc add dev #{link_name} root netem #{netem}")
    end

    def link_exit(node, link_name, link_attributes)
      netem = link_attributes['netem']
      return unless netem
      node.spawn("tc qdisc del dev #{link_name} root netem #{netem}")
    end
  end
end
