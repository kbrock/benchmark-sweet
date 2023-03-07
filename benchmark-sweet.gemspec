
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "benchmark/sweet/version"

Gem::Specification.new do |spec|
  spec.name          = "benchmark-sweet"
  spec.version       = Benchmark::Sweet::VERSION
  spec.authors       = ["Keenan Brock"]
  spec.email         = ["keenan@thebrocks.net"]

  spec.summary       = %q{Suite to run multiple benchmarks}
  spec.description   = <<-EOF
  Benchmark Sweet is a suite to run multiple kinds of metrics that allows for the generation
  of complex comparisons. It can be configured to run memory, sql query, and ips benchmarks
  on a common set of code. These data can be collected across multiple runs with numerous
  supported ruby or gem versions.
EOF

  spec.homepage      = "https://github.com/kbrock/benchmark-sweet"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "http://github.com/kbrock/benchmark-sweet"
    spec.metadata["changelog_uri"] = "http://github.com/kbrock/benchmark-sweet/CHANGELOG.md"
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "sqlite3"

  spec.add_runtime_dependency "benchmark-ips", "~> 2.8.2"
  spec.add_runtime_dependency "memory_profiler", "~> 0.9.0"
  spec.add_runtime_dependency "activesupport"         # for {}.symbolize_keys! - want to remove
end
