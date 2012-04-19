module Dor
  module Upgradable
    extend ActiveSupport::Concern

    # The Upgradable mixin is responsible for making sure all DOR objects know 
    # how to upgrade themselves to the latest Chimera/DOR content standards.
    # To add a new set up upgrades, add a new begin...end block with a comment
    # denoting the version of the dor-services that will introduce the change.
    # Different types of upgrades should go in different methods:
    # 
    # * Cross-model updates in Dor::Upgradable#upgrade
    # * Model-specific updates in [ModelClass]#upgrade_object
    # * Datastream-specific updates in [DatastreamClass]#upgrade_datastream
    
    def upgrade!
      begin # All versions
        self.upgrade_object
        self.upgrade_datastreams
        self.save
      end
    end
    
    # Override upgrade_object in models to provide model-specific upgrade logic
    def upgrade_object
    end

    def upgrade_datastreams
      self.datastreams.each do |ds|
        if ds.respond_to? :upgrade_datastream
          ds.upgrade_datastream
        end
      end
    end
  end
end
