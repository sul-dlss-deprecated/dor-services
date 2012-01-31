module Dor
  module Governable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships
    
    included do
      belongs_to :admin_policy_object, :class_name => 'Dor::AdminPolicyObject', :property => :is_governed_by
#      has_relationship 'admin_policy_object', :is_governed_by
    end
  
    def initiate_apo_workflow(name)
      wf_xml = admin_policy_object.datastreams['administrativeMetadata'].ng_xml.xpath(%{//workflow[@id="#{name}"]}).first.to_xml
      Dor::WorkflowService.create_workflow('dor',self.pid,name,wf_xml)
    end

  end
end
