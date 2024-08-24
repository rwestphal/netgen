module Netgen
  class PluginHolod < Plugin
    def name
      'holod'
    end

    def config_options
      {
        'bindir-daemon' => String,
        'bindir-cli' => String,
        'sysconfdir' => String,
        'localstatedir' => String,
        'user' => String,
        'group' => String,
        'logdir' => String
      }
    end

    def default_config
      {
        'bindir-daemon' => '/mnt/renato/git/rust/holo/target/debug',
        'bindir-cli' => '/mnt/renato/git/rust/holo-cli/target/debug',
        'sysconfdir' => '/etc/holod',
        'localstatedir' => '/var/run/holo',
        'user' => 'holo',
        'group' => 'holo',
        'logdir' => "#{Config::NETGEN_RUNSTATEDIR}/holod-logs"
      }
    end

    def topology_init(topology)
      super
      setup_dirs
    end

    def node_init(node)
      return unless node.attributes['holod']
      node.mount(@cfg['sysconfdir'])
      node.mount(@cfg['localstatedir'], @cfg['user'], @cfg['group'])
      node.mount('/var/log')
      create_config_files(node)
    end

    def node_start(node)
      holod_attr = node.attributes['holod']
      return unless holod_attr
      return if holod_attr.dig('run') == false
      delay = holod_attr.dig('delay') || 3

      Netgen.log_info("starting holod", plugin: self, node: node)
      out = "#{@cfg['logdir']}/#{node.name}.out"
      err = "#{@cfg['logdir']}/#{node.name}.err"
      node.spawn("#{perf(node)} #{@cfg['bindir-daemon']}/holod", env: {"RUST_LOG" => "holo=trace", "RUST_BACKTRACE" => "1"}, options: { out: out, err: err })

      # Enter configuration.
      config_path = "#{node.mount_point}/#{@cfg['sysconfdir']}/holod.config"
      node.spawn("#{@cfg['bindir-cli']}/holo-cli --file #{config_path}", delay: delay)
    end

    def node_exit(node)
      return unless node.attributes['holod']
      #node.umount(@cfg['sysconfdir'])
      #node.umount(@cfg['localstatedir'])

      perf_gen_flamegraphs(node)
    end

    def setup_dirs
      FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
      FileUtils.mkdir_p(@cfg['sysconfdir'])
      FileUtils.mkdir_p(@cfg['localstatedir'])
      FileUtils.mkdir_p(@cfg['logdir'])
      #FileUtils.chown_R(@cfg['user'], @cfg['group'], @cfg['localstatedir'])
      FileUtils.chown_R(@cfg['user'], @cfg['group'], @cfg['logdir'])

      #FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
      FileUtils.rm_rf(Netgen.config.options['perf_dir'])
      FileUtils.mkdir_p(Netgen.config.options['perf_dir'])
    end

    def create_config_files(node)
      config = @attributes.dig('base-config') || ''
      config += node.attributes.dig('holod', 'config') || ''
      config_replace_variables(config, node.name, @cfg['logdir'])

      path = "#{node.mount_point}/#{@cfg['sysconfdir']}/holod.config"
      File.open(path, 'w') { |file| file.write(config) }
    end

    def config_replace_variables(config, node_name, logdir)
      config.gsub!('%(node)', node_name)
      config.gsub!('%(logdir)', logdir)
    end

    def perf(node)
      return '' unless @attributes['perf'] ||
                       node.attributes.dig('holod', 'perf')

      perf_data = "#{perf_basename(node)}.data"
      "perf record -F 99 -g --call-graph=dwarf -o #{perf_data} -- "
    end

    def perf_basename(node)
      "#{Netgen.config.options['perf_dir']}/#{node.name}-holod-perf"
    end

    def perf_gen_flamegraphs(node)
      return unless node.attributes['holod']
      return if perf(node) == ''
      perf_data = "#{perf_basename(node)}.data"
      out_perf = "#{perf_basename(node)}.perf"
      out_folded = "#{perf_basename(node)}.folded"
      out_svg = "#{perf_basename(node)}.svg"
      sleep 1
      node.execute("perf script -i #{perf_data} > #{out_perf}")
      node.execute("stackcollapse-perf.pl #{out_perf} > #{out_folded}")
      node.execute("flamegraph.pl #{out_folded} > #{out_svg}")
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
    end

    def autogen_node(type, node_name, node, node_index)
      return unless type == Autogen::Router
      return unless @autogen['config']
      node['holod'] ||= {}
      node['holod'] = {}
      config = @autogen['config'] || ''
      node['holod']['config'] = config
    end

    def autogen_link(node, name, _local_attr, remote_attr)
      config = @autogen['config-per-interface']
      return unless config
      config = config.gsub('%(interface)', name)
      config = config.gsub('%(peer-v4)', remote_attr['ipv4'].split('/').first) if remote_attr['ipv4']
      config = config.gsub('%(peer-v6)', remote_attr['ipv6'].split('/').first) if remote_attr['ipv6']
      node['holod']['config'] += config
    end

    def autogen_loopback(node, node_index, name, attr)
      config = @autogen['config-per-loopback']
      return unless config
      config = config.gsub('%(interface)', name)
      config = config.gsub('%(node-index)', "#{node_index}")
      config = config.gsub('%(address-v4)', attr['ipv4'].split('/').first) if attr['ipv4']
      config = config.gsub('%(address-v6)', attr['ipv6'].split('/').first) if attr['ipv6']
      config = config.gsub('%(prefix-v4)', attr['ipv4']) if attr['ipv4']
      config = config.gsub('%(prefix-v6)', attr['ipv6']) if attr['ipv6']
      node['holod']['config'] += config
    end

    #def autogen_stub(node, node_index, stub_index, name, attr)
    #end
  end
end
