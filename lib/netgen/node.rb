module Netgen
  class Node
    attr_reader :index
    attr_reader :name
    attr_reader :attributes
    attr_reader :ns

    @global_index = -1
    def self.next_index
      @global_index += 1
    end

    def initialize(name, attributes)
      @index = Node.next_index
      @name = name
      @attributes = attributes
      @ns = LinuxNamespace.new
      @ns.fork_and_unshare do
        Process.setproctitle("netgen-#{@name}")
        trap(:INT, :IGNORE)
        trap(:TERM) { exit }
        # This is the init process of this node. We need to reap the zombies.
        trap(:CHLD) { Process.wait }
        sleep
      end
    end

    # Node cleanup.
    def cleanup
      return unless @attributes['links']
      @attributes['links'].each do |link_name, link_attributes|
        next unless link_attributes
        Netgen.plugins.each do |plugin|
          plugin.link_exit(self, link_name, link_attributes)
        end
      end
      Netgen.plugins.each { |plugin| plugin.node_exit(self) }
    end

    # Check if the topology is valid or not.
    def check_consistency(nodes); end

    # Call the 'node_init' method of all plugins.
    def setup
      FileUtils.mkdir_p(mount_point)
      #execute('sysctl -wq net.core.wmem_max=83886080')
      Netgen.plugins.each { |plugin| plugin.node_init(self) }
    end

    # Call the 'node_start' method of all plugins.
    def start
      # XXX MOVE
      Netgen.plugins.each { |plugin| plugin.node_start(self) }
    end

    # Create node's links.
    def setup_links(nodes)
      return unless @attributes['links']
      @attributes['links'].each do |link_name, link_attributes|
        link_attributes ||= {}
        peer = link_attributes.dig('peer')
        if peer
          setup_p2p_link(link_name, nodes[peer[0]], peer[1])
        elsif link_name != "lo"
          setup_stub_link(link_name, link_attributes)
        end
        execute("ip link set dev #{link_name} up")

        # XXX: should be a plugin
        vrf = link_attributes.dig('vrf')
        execute("ip link set dev #{link_name} master #{vrf}") if vrf

        Netgen.plugins.each do |plugin|
          plugin.link_init(self, link_name, link_attributes)
        end
      end
    end

    # Create a link connecting this node to another one.
    def setup_p2p_link(link_name, peer_node, peer_link)
      return if @index > peer_node.index
      execute("ip link add dev #{link_name} type veth peer name netgen-tmp")
      execute("ip link set dev netgen-tmp name #{peer_link} "\
              "netns #{peer_node.ns.pid}", pid: false)
    end

    # Create a stub link (i.e. a disconnected link).
    def setup_stub_link(link_name, link_attributes)
      type = link_attributes.dig('type') || 'none'
      case type
      when 'vrf'
        table = link_attributes.dig('table')
        # XXX: check if table is undefined (JSON schema?)
        execute("ip link add name #{link_name} type vrf table #{table}")
        #execute("ip rule add oif #{link_name} table #{table}")
        #execute("ip rule add iif #{link_name} table #{table}")
      else
        execute("ip link add name #{link_name} type dummy")
      end
    end

    # Execute a given command on this node and wait until it's done.
    def execute(command, options: {}, mnt: true, pid: true, net: true)
      Netgen.log_debug("execute '#{command}'", node: self)
      command.prepend(nsenter(mnt: mnt, pid: pid, net: net))
      system(command, options)
    rescue SystemCallError => e
      $stderr.puts "System call error:: #{e.message}"
      $stderr.puts e.backtrace
      exit(1)
    end

    # Spawn the given command under this node.
    # When this node is deleted, all non-detached child processes are
    # automatically killed.
    def spawn(command, env: {}, options: {}, delay: nil, mnt: true, pid: true, net: true)
      command.prepend(nsenter(mnt: mnt, pid: pid, net: net))

      # Sleep on a separate thread if necessary
      if delay
        Thread.new do
          sleep delay
          do_spawn(command, env: env, options: options)
        end
      else
        do_spawn(command, env: env, options: options)
      end
    rescue SystemCallError => e
      $stderr.puts "System call error:: #{e.message}"
      $stderr.puts e.backtrace
      exit(1)
    end

    def do_spawn(command, env: {}, options: {})
      Netgen.log_debug("spawn '#{command}'", node: self)
      pid = Process.spawn(env, command, options)
      Process.detach(pid)
    end

    # Workaround to change the mount namespace of the child processes since
    # setns(2) with CLONE_NEWNS doesn't work for multithreaded programs.
    # nsenter(1) is a standard tool from the util-linux package.
    def nsenter(mnt: false, pid: false, net: false)
      return "" unless mnt || pid || net
      cmd = "nsenter -t #{@ns.pid} "
      cmd += "--mount " if mnt
      cmd += "--pid " if pid
      cmd += "--net " if net
      cmd
    end

    # Root path to the node's bind mounts.
    def mount_point
      "#{Netgen.config.options['netgen_runstatedir']}/mounts/#{@name}"
    end

    # Bind mount a path under this node's mount namespace (e.g. /etc, /var/run).
    def mount(path, user = nil, group = nil)
      source = "#{mount_point}/#{path}"
      FileUtils.mkdir_p(source)
      FileUtils.chown_R(user, group, source) if user || group
      execute("mount --bind #{source} #{path}")
    end

    # Umount previously mounted path. Use --lazy so this doesn't fail when the
    # mount point is still busy (e.g. a shell session on a dead node).
    def umount(path)
      execute("umount --lazy #{path}")
      FileUtils.rm_rf("#{mount_point}/#{path}")
    end

    # Suspend or pause the current node.
    def suspend; end

    # Resume operation after being paused.
    def resume; end

    # Private methods
    private :do_spawn
  end
end
