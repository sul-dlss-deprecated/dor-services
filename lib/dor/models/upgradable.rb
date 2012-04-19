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
      begin # 3.5.0
        # Assign hydra:isGovernedBy based on identityMetadata/adminPolicy
        if self.admin_policy_object_ids.empty?
          apo_id = self.identityMetadata.adminPolicy.first
          self.admin_policy_object_append("info:fedora/#{apo_id}") unless apo_id.nil?
        end
      
        # Assign sulair:hasAgreement based on identityMetadata/agreementId
        if self.agreement_ids.empty?
          agreement_id = self.identityMetadata.agreementId.first
          self.agreement_append("info:fedora/#{agreement_id}") unless agreement_id.nil?
        end
      
        # Touch workflows datastream to ensure it gets saved
        if self.workflows.new?
          self.workflows.content
        end
      
        # Remove individual *WF datastreams
        datastreams.each_pair do |dsid,ds| 
          if ds.controlGroup == 'E' and dsid =~ /WF$/
            ds.delete 
          end
        end
      end
      
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
