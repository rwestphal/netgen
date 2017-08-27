module Netgen
  class PluginBird < Plugin
    def name
      'bird'
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
        'sysconfdir' => '/etc/bird',
        'localstatedir' => '/var/run/bird',
        'user' => 'bird',
        'group' => 'bird',
        'logdir' => "#{Config::NETGEN_RUNSTATEDIR}/birdlogs"
      }
    end

    def topology_init(topology)
      super
      #setup_dirs
    end

    def node_init(node)
      return unless node.attributes['bird']
      node.mount(@cfg['sysconfdir'], @cfg['user'], @cfg['group'])
      node.mount(@cfg['localstatedir'], @cfg['user'], @cfg['group'])
      create_config_files(node)
    end

    def node_start(node)
      attributes = node.attributes['bird']
      return unless attributes
      ['bird', 'bird6'].each do |daemon|
        next unless attributes[daemon]
        Netgen.log_info("starting #{daemon}", plugin: self, node: node)
        node.spawn(daemon, options: { out: '/dev/null', err: '/dev/null' })
      end
    end

    def node_exit(node)
      return unless node.attributes['bird']
      #node.umount(@cfg['sysconfdir'])
      #node.umount(@cfg['localstatedir'])
    end

    def setup_dirs
      FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
      FileUtils.mkdir_p(@cfg['sysconfdir'])
      FileUtils.mkdir_p(@cfg['localstatedir'])
      FileUtils.mkdir_p(@cfg['logdir'])
      # XXX: might fail
      FileUtils.chown_R(@cfg['user'], @cfg['group'], @cfg['logdir'])
      FileUtils.rm(Dir.glob("#{@cfg['logdir']}/*.log"))
    end

    def create_config_files(node)
      attributes = node.attributes['bird']
      ['bird', 'bird6'].each do |daemon|
        create_config_file(node, daemon, attributes[daemon])
      end
    end

    def create_config_file(node, daemon, attributes)
      return unless attributes

      config = ''
      config = @attributes.dig('base-configs', 'all') || ''
      config += @attributes.dig('base-configs', daemon) || ''
      config += attributes['config'] || ''
      config_replace_variables(config, node.name, @cfg['logdir'])

      path = "#{node.mount_point}/#{@cfg['sysconfdir']}/#{daemon}.conf"
      File.open(path, 'w') { |file| file.write(config) }
    end

    def config_replace_variables(config, node_name, logdir)
      config.gsub!('%(node)', node_name)
      config.gsub!('%(logdir)', logdir)
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
    end

    def autogen_node(type, _node_name, node, node_index)
      return unless type == Autogen::Router
      ['bird', 'bird6'].each do |daemon|
        next unless @autogen[daemon]
        node['bird'] ||= {}
        node['bird'][daemon] = {}
        config = @autogen[daemon]['config'] || ''
        node['bird'][daemon]['config'] = config
      end
    end

    def autogen_link(node, name, _local_attr, remote_attr)
      ['bird', 'bird6'].each do |daemon|
        next unless @autogen[daemon]
        config = @autogen[daemon]['config-per-interface']
        next unless config
        config = config.gsub('%(interface)', name)
        config = config.gsub('%(peer-v4)', remote_attr['ipv4'].split('/').first) if remote_attr['ipv4']
        config = config.gsub('%(peer-v6)', remote_attr['ipv6'].split('/').first) if remote_attr['ipv6']
        node['bird'][daemon]['config'] += config
      end
    end

    def autogen_loopback(node, _node_index, name, attr)
      ['bird', 'bird6'].each do |daemon|
        next unless @autogen[daemon]
        config = @autogen[daemon]['config-per-loopback']
        next unless config
        config = config.gsub('%(interface)', name)
        config = config.gsub('%(address-v4)', attr['ipv4'].split('/').first) if attr['ipv4']
        config = config.gsub('%(address-v6)', attr['ipv6'].split('/').first) if attr['ipv6']
        node['bird'][daemon]['config'] += config
      end
    end
  end
end
