module Netgen
  class PluginTmux < Plugin
    def name
      'tmux'
    end

    def config_options
      {
        'file' => String,
        'panels-per-node' => Fixnum
      }
    end

    def default_config
      {
        'file' => "#{Config::NETGEN_RUNSTATEDIR}/tmux.sh",
        'panels-per-node' => 1
      }
    end

    def topology_exit
      FileUtils.rm(@cfg['file'])
    end

    def topology_start
      Netgen.log_info('generating script', plugin: self)
      content = generate_script
      write_script(content, @cfg['file'])
    end

    def generate_script
      content = "#!/bin/sh\n"
      content += "export TMUX=\n"
      nodes = Netgen.topology.nodes
      nodes.values.each do |node|
        content += if node == nodes.values.first
                     'tmux new-session -d -s netgen '
                   else
                     'tmux new-window -t netgen '
                   end
        command = "nsenter -t #{node.ns.pid} --mount --pid --net --wd=. bash"
        content += "-n #{node.name} '#{command}'\n"
        (@cfg['panels-per-node'] - 1).times do
          content += "tmux split-window -h '#{command}'\n"
        end
        content += "tmux select-layout even-horizontal\n"
      end
      content += "tmux attach-session -d -t netgen\n"
    end

    def write_script(content, path)
      File.open(path, 'w') { |file| file.write(content) }
      FileUtils.chmod 'u=+x', path
    end
  end
end
