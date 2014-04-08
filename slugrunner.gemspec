# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slugrunner/version'

Gem::Specification.new do |spec|
  spec.name          = "slugrunner"
  spec.version       = Slugrunner::VERSION
  spec.authors       = ["lxfontes"]
  spec.email         = ["lxfontes@gmail.com"]
  spec.summary       = %q{Running application slugs}
  spec.homepage      = "https://github.com/lxfontes/slugrunner-rb"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency 'trollop'
end
