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
  end
end
