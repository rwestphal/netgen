# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'netgen/version'

Gem::Specification.new do |spec|
  spec.name          = 'netgen'
  spec.version       = Netgen::VERSION
  spec.authors       = ['Renato Westphal']
  spec.email         = ['renato@opensourcerouting.org']

  spec.summary       = %q{XXX: Write a short summary, because Rubygems requires one.}
  spec.description   = %q{XXX: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/rwestphal/netgen"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "XXX: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3.0'
  spec.add_dependency 'ffi'
  spec.add_development_dependency 'bundler', '>= 2.5.20'
  spec.add_development_dependency 'rake', '~> 13.2.0'
  spec.add_development_dependency 'rspec', '~> 3.13.0'
end
