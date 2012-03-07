module Dor  
  module Governable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships
    
    included do
      has_relationship 'admin_policy_object', :is_governed_by
      has_relationship 'collection', :is_member_of_collection
      has_relationship 'set', :is_member_of
    end
  
    def initiate_apo_workflow(name)
      wf_xml = admin_policy_object.first.datastreams['administrativeMetadata'].ng_xml.xpath(%{//workflow[@id="#{name}"]}).first.to_xml
      Dor::WorkflowService.create_workflow('dor',self.pid,name,wf_xml, :create_ds => !self.new_object?)
    end

  end
end
