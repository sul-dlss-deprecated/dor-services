# frozen_string_literal: true

module Dor
  module Assembleable
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    def initialize_workspace(source = nil)
      druid = DruidTools::Druid.new(pid, Config.stacks.local_workspace_root)
      if source.nil?
        druid.mkdir
      else
        druid.mkdir_with_final_link(source)
      end
    end
    deprecation_deprecate initialize_workspace: 'This functionality has moved to dor_services_app'
  end
end
