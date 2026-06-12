# typed: strict
# frozen_string_literal: true

require "toml-rb"

module Dependabot
  module Cargo
    module Helpers
      extend T::Sig

      # Strip per-registry `credential-provider` settings from .cargo/config.toml.
      #
      # Users may have entries like:
      #   [registries.my-registry]
      #   credential-provider = "cargo:token"
      #
      # These per-registry settings override the global CARGO_REGISTRY_GLOBAL_CREDENTIAL_PROVIDERS env var,
      # causing Cargo to look up tokens locally. Since the dependabot proxy handles all registry authentication
      # transparently, we remove these so Cargo makes plain unauthenticated requests that the proxy can intercept.
      sig { params(config_content: String).returns(String) }
      def self.sanitize_cargo_config(config_content)
        parsed = TomlRB.parse(config_content)
        return config_content unless parsed.is_a?(Hash)

        registries = parsed["registries"]
        if registries.is_a?(Hash)
          registries.each_value do |registry_config|
            registry_config.delete("credential-provider") if registry_config.is_a?(Hash)
          end
        end

        # Also strip credential-provider from [registry] (crates.io default registry). Users who `cargo publish`
        # from CI may have this set. It's a per-registry override that takes precedence over the global env var,
        # so we need to remove it to prevent Cargo from trying to look up a token.
        registry = parsed["registry"]
        registry.delete("credential-provider") if registry.is_a?(Hash)

        TomlRB.dump(parsed)
      rescue TomlRB::Error => e
        raise Dependabot::DependencyFileNotParseable.new(
          ".cargo/config.toml",
          "Failed to parse Cargo config file: #{e.message}"
        )
      end
    end
  end
end
