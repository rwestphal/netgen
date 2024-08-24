module Netgen
  class PluginFrr < Plugin
    @@daemons = %w[
      zebra
      bgpd
      ospfd
      ospf6d
      isisd
      fabricd
      ripd
      ripngd
      eigrpd
      pimd
      ldpd
      nhrpd
      babeld
      bfdd
      sharpd
      staticd
      pbrd
      pathd
      mgmtd
      vrrpd
    ]

    def name
      'frr'
    end

    def config_options
      {
        'sysconfdir' => String,
        'localstatedir' => String,
        'user' => String,
        'group' => String,
        'logdir' => String
      }
    end

    def default_config
      {
        'sysconfdir' => '/etc/frr',
        'localstatedir' => '/var/run/frr',
        'user' => 'frr',
        'group' => 'frr',
        'logdir' => "#{Config::NETGEN_RUNSTATEDIR}/frrlogs"
      }
    end

    def topology_init(topology)
      super
      setup_dirs
    end

    def node_init(node)
      return unless node.attributes['frr']
      node.mount(@cfg['sysconfdir'], @cfg['user'], @cfg['group'])
      node.mount(@cfg['localstatedir'], @cfg['user'], @cfg['group'])
      create_config_files(node)
    end

    def node_start(node)
      frr_attr = node.attributes['frr']
      return unless frr_attr
      @@daemons.each do |daemon|
        next unless frr_attr.has_key?(daemon) or daemon == "mgmtd"
        next if frr_attr.dig(daemon, 'run') == false
        delay = frr_attr.dig(daemon, 'delay') || nil
        args = frr_attr.dig(daemon, 'args') || ''

        out = "#{@cfg['logdir']}/#{node.name}-#{daemon}.out"
        err = "#{@cfg['logdir']}/#{node.name}-#{daemon}.err"

        if delay
          Netgen.log_info("scheduling to start #{daemon} in #{delay} seconds",
                          plugin: self, node: node)
        else
          Netgen.log_info("starting #{daemon}", plugin: self, node: node)
        end
        node.spawn("#{valgrind(node, daemon)}#{perf(node, daemon)}#{daemon} #{args}",
                   options: { out: out, err: err }, delay: delay)
      end
      node.spawn("vtysh -b", options: { out: '/dev/null', err: '/dev/null' }, delay: 3)
    end

    def node_exit(node)
      return unless node.attributes['frr']
      #node.umount(@cfg['sysconfdir'])
      #node.umount(@cfg['localstatedir'])

      perf_gen_flamegraphs(node)
    end

    def setup_dirs
      FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
      FileUtils.mkdir_p(@cfg['sysconfdir'])
      FileUtils.mkdir_p(@cfg['localstatedir'])
      FileUtils.mkdir_p(@cfg['logdir'])
      FileUtils.chown_R(@cfg['user'], @cfg['group'], @cfg['logdir'])

      #FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
      FileUtils.rm_rf(Netgen.config.options['perf_dir'])
      FileUtils.mkdir_p(Netgen.config.options['perf_dir'])
    end

    def create_config_integrated(node)
      config = @attributes.dig('base-config') || ''
      config += node.attributes.dig('frr', 'config') || ''
      config_replace_variables(config, node.name, "%(daemon)", @cfg['logdir'])

      path = "#{node.mount_point}/#{@cfg['sysconfdir']}/frr.conf"
      File.open(path, 'w') { |file| file.write(config) }
    end

    def create_config_per_daemon(node)
      @@daemons.each do |daemon|
        next unless node.attributes.dig('frr', daemon)

        config = @attributes.dig('base-configs', 'all') || ''
        config += @attributes.dig('base-configs', daemon) || ''
        config += node.attributes.dig('frr', daemon, 'config') || ''
        config_replace_variables(config, node.name, daemon, @cfg['logdir'])

        path = "#{node.mount_point}/#{@cfg['sysconfdir']}/#{daemon}.conf"
        File.open(path, 'w') { |file| file.write(config) }
      end
    end

    def create_config_files(node)
      if node.attributes.dig('frr', 'config')
        create_config_integrated(node)
      else
        create_config_per_daemon(node)
      end
      FileUtils.touch("#{node.mount_point}/#{@cfg['sysconfdir']}/vtysh.conf")
    end

    def config_replace_variables(config, node_name, daemon, logdir)
      config.gsub!('%(node)', node_name)
      config.gsub!('%(daemon)', daemon)
      config.gsub!('%(logdir)', logdir)
    end

    def valgrind(node, daemon)
      return '' unless @attributes['valgrind'] ||
                       node.attributes.dig('frr', 'valgrind') ||
                       node.attributes.dig('frr', daemon, 'valgrind')

      params = Netgen.config.options['valgrind_params']
      logfile = "#{@cfg['logdir']}/#{node.name}-#{daemon}-valgrind.log"
      #callgrind_out_file = "#{@cfg['logdir']}/#{node.name}-#{daemon}-callgrind.out"
      "valgrind #{params} --log-file='#{logfile}' "
      #"valgrind #{params} --log-file='#{logfile}' --callgrind-out-file='#{callgrind_out_file}' "
    end

    def perf(node, daemon)
      return '' unless @attributes['perf'] ||
                       node.attributes.dig('frr', 'perf') ||
                       node.attributes.dig('frr', daemon, 'perf')

      perf_data = "#{perf_basename(node, daemon)}.data"
      "perf record -g --call-graph=dwarf -o #{perf_data} -- "
    end

    def perf_basename(node, daemon)
      "#{Netgen.config.options['perf_dir']}/#{node.name}-#{daemon}-perf"
    end

    def perf_gen_flamegraphs(node)
      @@daemons.each do |daemon|
        next unless node.attributes.dig('frr', daemon)
        return if perf(node, daemon) == ''
        perf_data = "#{perf_basename(node, daemon)}.data"
        out_perf = "#{perf_basename(node, daemon)}.perf"
        out_folded = "#{perf_basename(node, daemon)}.folded"
        out_svg = "#{perf_basename(node, daemon)}.svg"
        node.execute("perf script -i #{perf_data} > #{out_perf}")
        node.execute("stackcollapse-perf.pl #{out_perf} > #{out_folded}")
        node.execute("flamegraph.pl #{out_folded} > #{out_svg}")
      end
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
    end

    def autogen_node(type, node_name, node, node_index)
      return unless type == Autogen::Router

      @@daemons.each do |daemon|
        next unless @autogen[daemon]
        node['frr'] ||= {}
        node['frr'][daemon] = {}
        config = @autogen[daemon]['config'] || ''
        config = config.gsub('%(bgp-node-index)', "#{node_index}")
        config = config.gsub('%(isis-node-index)', node_index.to_s.rjust(4, '0'))
        gen_static_routes(config, node_index) if daemon == 'zebra'
        node['frr'][daemon]['config'] = config
      end
    end

    def autogen_link(node, name, _local_attr, remote_attr)
      @@daemons.each do |daemon|
        next unless @autogen[daemon]
        config = @autogen[daemon]['config-per-interface']
        next unless config
        config = config.gsub('%(interface)', name)
        config = config.gsub('%(peer-v4)', remote_attr['ipv4'].split('/').first) if remote_attr['ipv4']
        config = config.gsub('%(peer-v6)', remote_attr['ipv6'].split('/').first) if remote_attr['ipv6']
        node['frr'][daemon]['config'] += config
      end
    end

    def autogen_loopback(node, node_index, name, attr)
      @@daemons.each do |daemon|
        next unless @autogen[daemon]
        config = @autogen[daemon]['config-per-loopback']
        next unless config
        config = config.gsub('%(interface)', name)
        config = config.gsub('%(node-index)', "#{node_index}")
        config = config.gsub('%(address-v4)', attr['ipv4'].split('/').first) if attr['ipv4']
        config = config.gsub('%(address-v6)', attr['ipv6'].split('/').first) if attr['ipv6']
        config = config.gsub('%(prefix-v4)', attr['ipv4']) if attr['ipv4']
        config = config.gsub('%(prefix-v6)', attr['ipv6']) if attr['ipv6']
        node['frr'][daemon]['config'] += config
      end
    end

    def autogen_stub(node, node_index, stub_index, name, attr)
      @@daemons.each do |daemon|
        next unless @autogen[daemon]
        config = @autogen[daemon]['config-per-stub']
        next unless config
        config = config.gsub('%(interface)', name)
        config = config.gsub('%(node-index)', "#{node_index}")
        config = config.gsub('%(stub-index)', "#{stub_index}")
        config = config.gsub('%(address-v4)', attr['ipv4'].split('/').first) if attr['ipv4']
        config = config.gsub('%(address-v6)', attr['ipv6'].split('/').first) if attr['ipv6']
        config = config.gsub('%(prefix-v4)', attr['ipv4']) if attr['ipv4']
        config = config.gsub('%(prefix-v6)', attr['ipv6']) if attr['ipv6']
        node['frr'][daemon]['config'] += config
      end
    end

    def gen_static_routes(config, node_index)
      params = @autogen['zebra']['static-route-generator']
      return unless params
      gen_static_routes_af(config, node_index, params['ipv4'], Socket::AF_INET)
      gen_static_routes_af(config, node_index, params['ipv6'], Socket::AF_INET6)
    end

    def gen_static_routes_af(config, node_index, params, af)
      return unless params

      routes = IPCalc.new(af, params['start'], params['prefixlen'],
                          params['step'], params['step-by-router'],
                          params['number'])
      routes.each(node_index) do |prefix|
        config << "ip route #{prefix} #{params['nexthop']}\n"
      end
    end
  end
end
