# frozen_string_literal: true

require_relative "lib/thor/interactive/version"

Gem::Specification.new do |spec|
  spec.name = "thor-interactive"
  spec.version = Thor::Interactive::VERSION
  spec.authors = ["Chris Petersen"]
  spec.email = ["chris@petersen.io"]

  spec.summary = "Turn any Thor CLI into an interactive REPL with persistent state and auto-completion"
  spec.description = "A gem that automatically converts Thor command-line applications into interactive REPLs, maintaining state between commands and providing auto-completion for commands and parameters."
  spec.homepage = "https://github.com/scientist-labs/thor-interactive"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/scientist-labs/thor-interactive"
  spec.metadata["changelog_uri"] = "https://github.com/scientist-labs/thor-interactive/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "reline", "~> 0.3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
