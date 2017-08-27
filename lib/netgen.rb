require_relative 'netgen/autogen'
require_relative 'netgen/config'
require_relative 'netgen/ipcalc'
require_relative 'netgen/libc'
require_relative 'netgen/linux_namespace'
require_relative 'netgen/node'
require_relative 'netgen/router'
require_relative 'netgen/switch'
require_relative 'netgen/topology'
require_relative 'netgen/version'

module Netgen
  class << self
    attr_accessor :topology
    attr_accessor :config
    attr_accessor :output
    attr_accessor :plugins
    attr_accessor :debug_mode

    Netgen.debug_mode = false
    Netgen.plugins = []

    def log_err(msg, node: node = nil, plugin: plugin = nil)
      msg.prepend("node #{node.name}: ") if node
      msg.prepend("plugin: #{plugin.name}: ") if plugin
      $stderr.puts msg
    end

    def log_info(msg, node: node = nil, plugin: plugin = nil)
      msg.prepend("node #{node.name}: ") if node
      msg.prepend("plugin: #{plugin.name}: ") if plugin
      puts msg
    end

    def log_debug(msg, node: node = nil, plugin: plugin = nil)
      return unless @debug_mode
      msg.prepend("plugin: #{plugin.name}: ") if plugin
      msg.prepend("node #{node.name}: ") if node
      puts "debug: #{msg}"
    end
  end
end

require_relative 'netgen/plugin'
#require_relative 'netgen/plugins/shell'
require_relative 'netgen/plugins/ethernet'
require_relative 'netgen/plugins/ipv4'
require_relative 'netgen/plugins/ipv6'
require_relative 'netgen/plugins/mpls'
require_relative 'netgen/plugins/netem'
require_relative 'netgen/plugins/tcpdump'
require_relative 'netgen/plugins/bgpsimple'
require_relative 'netgen/plugins/frr'
require_relative 'netgen/plugins/bird'
require_relative 'netgen/plugins/iou'
require_relative 'netgen/plugins/dynamips'
require_relative 'netgen/plugins/tmux'
