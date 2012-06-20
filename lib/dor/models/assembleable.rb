module Dor
  module Assembleable
    
    def initialize_workspace(source=nil)
      if(source.nil?)
        druid = DruidTools::Druid.new(self.pid,Config.stacks.local_workspace_root)
        druid.mkdir
      else
        druid = DruidTools::Druid.new(self.pid, Config.stacks.local_workspace_root)
        druid.mkdir_with_final_link(source)
      end
    end
  end
end