module Dor
  module Assembleable
    def initialize_workspace(source = nil)
      druid = DruidTools::Druid.new(pid, Config.stacks.local_workspace_root)
      if source.nil?
        druid.mkdir
      else
        druid.mkdir_with_final_link(source)
      end
    end
  end
end
