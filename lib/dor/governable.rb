module Dor
  class AdminPolicyObject < ::ActiveFedora::Base; end
  class Collection < ::ActiveFedora::Base; end
  class Set < ::ActiveFedora::Base; end
  
  module Governable
    extend ActiveSupport::Concern
    include ActiveFedora::Relationships
    
    included do
      belongs_to :admin_policy_object, :class_name => 'Dor::AdminPolicyObject', :property => :is_governed_by
      belongs_to :collection, :class_name => 'Dor::Collection', :property => :is_member_of_collection
      belongs_to :set, :class_name => 'Dor::Set', :property => :is_member_of
      has_relationship 'admin_policy_object', :is_governed_by, :type => Dor::AdminPolicyObject
      has_relationship 'collection', :is_member_of_collection, :type => Dor::Collection
      has_relationship 'set', :is_member_of, :type => Dor::Set
    end
  
    def initiate_apo_workflow(name)
      wf_xml = admin_policy_object.datastreams['administrativeMetadata'].ng_xml.xpath(%{//workflow[@id="#{name}"]}).first.to_xml
      Dor::WorkflowService.create_workflow('dor',self.pid,name,wf_xml)
    end

  end
end
