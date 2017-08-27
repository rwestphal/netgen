module Netgen
  class PluginIpv6 < Plugin
    def name
      'ipv6'
    end

    def node_init(node)
      node.spawn('sysctl -wq net.ipv6.conf.all.forwarding=1')
      node.spawn('sysctl -wq net.ipv6.conf.all.keep_addr_on_down=1')
    end

    def node_start(node)
      routes = node.attributes.dig('ipv6', 'routes')
      return unless routes
      routes.each do |route|
        node.spawn("ip -6 route add #{route}")
      end
    end

    def link_init(node, link_name, link_attributes)
      ipv6 = link_attributes['ipv6']
      return unless ipv6
      node.spawn("ip -6 addr add #{ipv6} dev #{link_name}")
    end

    def link_exit(node, link_name, link_attributes)
      ipv6 = link_attributes['ipv6']
      return unless ipv6
      node.spawn("ip -6 addr del #{ipv6} dev #{link_name}")
    end

    @subnet_index = -1
    def self.next_subnet
      @subnet_index += 1
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
      return unless parameters

      routes = parameters['routes']
      if routes
        @autogen['_routes'] = IPCalc.new(Socket::AF_INET6, routes['start'],
                                         routes['prefixlen'], routes['step'],
                                         routes['step-by-router'],
                                         routes['number'])
      end

      subnets = parameters['subnets']
      if subnets
        @autogen['subnets'] = IPCalc.new(Socket::AF_INET6, subnets['start'],
                                         subnets['prefixlen'], subnets['step'])
      end

      loopbacks = parameters['loopbacks']
      if loopbacks
        @autogen['loopbacks'] = IPCalc.new(Socket::AF_INET6, loopbacks['start'],
                                           128, loopbacks['step'])
      end

      stubs = parameters['stubs']
      if stubs
        @autogen['stubs'] = IPCalc.new(Socket::AF_INET6, stubs['start'],
                                       stubs['prefixlen'], stubs['step'],
                                       stubs['step-by-router'])
      end
    end

    def autogen_node(type, _node_name, node, node_index)
      return unless @autogen['_routes']
      node['ipv6'] ||= {}
      node['ipv6']['routes'] ||= []
      params = @autogen['routes']
      @autogen['_routes'].each(node_index) do |prefix|
        route = "#{prefix}"
        route += " via #{params['nexthop-addr']}" if params['nexthop-addr']
        route += " dev #{params['nexthop-if']}" if params['nexthop-if']
        route += " proto #{params['protocol']}" if params['protocol']
        node['ipv6']['routes'].push(route)
      end
    end

    def autogen_link(_node, _name, local_attr, remote_attr)
      return if local_attr['ipv6']
      return unless @autogen['subnets']

      @autogen['subnets'].fetch(self.class.next_subnet) do |calc, address|
        local = address + 1
        remote = address + 2
        local_attr['ipv6'] = calc.print(local)
        remote_attr['ipv6'] = calc.print(remote)
      end
    end

    def autogen_loopback(_node, node_index, _name, attr)
      return unless @autogen['loopbacks']
      attr['ipv6'] = @autogen['loopbacks'].fetch(node_index)
    end

    def autogen_stub(_node, node_index, stub_index, _name, attr)
      return unless @autogen['stubs']
      attr['ipv6'] = @autogen['stubs'].fetch(stub_index, node_index)
    end
  end
end
