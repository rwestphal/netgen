module Netgen
  class Config
    attr_reader :options
    NETGEN_RUNSTATEDIR = '/tmp/netgen'

    def initialize(path)
      @options = {}
      load(path)
    end

    # Load and parse the configuration file given as parameter.
    # Use default values for unspecified configuration entries.
    def load(path)
      config = YAML.load_file(path)
      config = default_config.merge(config)
      parse_config(config)
    rescue SystemCallError => e
      $stderr.puts "Error opening configuration file: #{e}"
      exit(1)
    rescue Psych::SyntaxError, ArgumentError => e
      $stderr.puts "Error parsing configuration file: #{e}"
      exit(1)
    end

    # Default configuration.
    def default_config
      {
        'netgen_runstatedir' => "#{NETGEN_RUNSTATEDIR}",
        'clean_exit' => 'false',
        'valgrind_params' => '--tool=memcheck --leak-check=full',
        'perf_dir' => "#{NETGEN_RUNSTATEDIR}/perf",
        'plugins' => {}
      }
    end

    # Parse configuration file.
    def parse_config(config)
      config_options = {
        'netgen_runstatedir' => String,
        'clean_exit' => String,
        'valgrind_params' => String,
        'perf_dir' => String,
        'plugins' => Hash
      }

      config.each do |name, value|
        Config.validate(name, value, config_options)
        if name == 'plugins'
          parse_plugins(value)
        else
          @options[name] = value
        end
      end
    end

    # Parse the 'plugins' section of the configuration file.
    def parse_plugins(config)
      config.each do |name, value|
        plugin = Netgen.plugins.find { |p| p.name == name }
        raise ArgumentError, "unknown plugin: #{plugin}" unless plugin
        plugin.parse_config(value)
      end
    end

    # Validate configuration entry.
    def self.validate(name, value, config_options)
      option = config_options[name]
      raise ArgumentError, "unknown option: #{name}" unless option
      unless value.class == option
        raise ArgumentError, "invalid value: #{value} (#{name})"
      end
    end
  end
end
