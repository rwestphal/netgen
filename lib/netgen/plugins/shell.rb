module Netgen
  class PluginShell < Plugin
    def name
      'shell'
    end

    def config_options
      {
      }
    end

    def default_config
      {
      }
    end

    def node_start(node)
      cmds = node.attributes['shell']
      return unless cmds
      cmds.each_line do |cmd|
        next if cmd.start_with?("#")
        node.execute("sh -c '" + cmd + "'")
      end
    end

    def autogen_parse(parameters)
      # TODO: validate
      @autogen = parameters || {}
    end

    def autogen_node(type, _node_name, node, node_index)
      return unless @autogen
      node['shell'] = @autogen
    end
  end
end
