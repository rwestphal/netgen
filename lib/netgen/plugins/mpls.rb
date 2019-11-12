module Netgen
  class PluginMpls < Plugin
    def name
      'mpls'
    end

    def node_init(node)
      node.spawn('modprobe mpls_router')
      node.spawn('modprobe mpls_iptunnel')
      node.spawn('sysctl -wq net.mpls.platform_labels=1048575')
    end

    def link_init(node, link_name, link_attributes)
      mpls = link_attributes['mpls']
      return unless mpls
      node.spawn("sysctl -wq net.mpls.conf.#{link_name}.input=1")
    end

    def link_exit(node, link_name, link_attributes)
      mpls = link_attributes['mpls']
      return unless mpls
      node.spawn("sysctl -wq net.mpls.conf.#{link_name}.input=0")
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
    end

    def autogen_link(_node, name, local_attr, remote_attr)
      return unless @autogen['enable']
      local_attr['mpls'] = true
    end

    def autogen_loopback(_node, node_index, _name, local_attr)
      return unless @autogen['enable']
      local_attr['mpls'] = true
    end
  end
end
