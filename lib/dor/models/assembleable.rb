module Dor
  module Assembleable
    
    def initialize_workspace(source=nil)
      if(source.nil?)
        druid = Druid.new(self.pid)
        druid.mkdir(Config.stacks.local_workspace_root)
      else
        druid = Druid.new(self.pid)
        druid.mkdir_with_final_link(source, Config.stacks.local_workspace_root)
      end
    end
  end
end