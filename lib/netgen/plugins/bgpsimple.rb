module Netgen
  class PluginBgpsimple < Plugin
    def name
      'bgpsimple'
    end

    def config_options
      {
        'path' => String,
      }
    end

    def default_config
      {
        'path' => 'bgp_simple.pl',
      }
    end

    def node_start(node)
      attr = node.attributes['bgpsimple']
      return unless attr
      # TODO: validate

      delay = attr['delay']
      sleep delay if delay.is_a?(Numeric)

      Netgen.log_info("starting bgp_simple.pl", plugin: self, node: node)

      command = @cfg['path']
      command += " -myas #{attr['myas']}"
      command += " -myip #{attr['myip']} -n #{attr['myip']}"
      command += " -peeras #{attr['peeras']}"
      command += " -peerip #{attr['peerip']}"
      command += " -keepalive #{attr['keepalive']}" if attr['keepalive']
      command += " -holdtime #{attr['holdtime']}" if attr['holdtime']
      command += " -p #{attr['file']}" if attr['file']
      command += " -nolisten"

      node.spawn(command, options: { out: '/dev/null', err: '/dev/null' })
    end
  end
end
