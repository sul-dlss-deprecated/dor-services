# frozen_string_literal: true

require 'yaml'

module Dor
  defaults = YAML.safe_load(File.read(File.expand_path('../../config/config_defaults.yml', __dir__))).deep_symbolize_keys
  Config = StaticConfig.new(defaults)
  ActiveFedora.configurator = Config
end
