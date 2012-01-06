module Dor
  module Processable
    extend ActiveSupport::Concern

    included do
      self.ds_specs.instance_eval do
        class << self
          alias_method :_retrieve, :[]
          def [](key)
            self._retrieve(key) || (key =~ /WF$/ ? { :type => WorkflowDs } : nil)
          end
        end
      end
    end
    
    # Self-aware datastream builders
    def build_datastream(datastream, force = false)
      ds = datastreams[datastream]
      if force or ds.new_object? or (ds.content.to_s.empty?)
        proc = "build_#{datastream}_datastream".to_sym
        if respond_to? proc
          content = self.send(proc, ds)
          ds.save
        end
      end
      return ds
    end

    def cleanup()
      CleanupService.cleanup(self)
    end

    def milestones
      Dor::WorkflowService.get_milestones('dor',self.pid)
    end
    
    def workflows
      datastreams.keys.select { |k| k =~ /WF$/ }
    end
  end
end
