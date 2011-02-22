require 'active_fedora'
require 'dor/suri_service'
require 'xml_models/identity_metadata/identity_metadata'
require 'xml_models/foxml'

module Dor

  class Base < ActiveFedora::Base
    
    class << self
      def register_object(object_type, content_model, admin_policy, label, agreement_id, parent = nil, source_id = {}, other_ids = {}, tags = [])
        pid = Dor::SuriService.mint_id

        idmd = IdentityMetadata.new
        idmd.objectTypes << object_type
        idmd.adminPolicyObjects << admin_policy
        idmd.agreementIds << agreement_id
        idmd.sourceId.source = source_id[:source]
        idmd.sourceId.value = source_id[:value]
        other_ids.each_pair { |name,value| idmd.add_identifier(name,value) }
        tags.each { |tag| idmd.add_tag(tag) }
        
        foxml = Foxml.new(pid, label, content_model, idmd.to_xml, parent)
        
        result = Fedora::Repository.instance.ingest(foxml.to_xml)
        new_object = begin
          self.load_instance(pid) 
        rescue ActiveFedora::ObjectNotFoundError
          nil
        end
        return { :result => result, :object => new_object }
      end
    end
    
    def initialize(attrs = {})
      unless attrs[:pid]
        attrs = attrs.merge!({:pid=>Dor::SuriService.mint_id})  
        @new_object=true
      else
        @new_object = attrs[:new_object] == false ? false : true
      end
      @inner_object = Fedora::FedoraObject.new(attrs)
      @datastreams = {}
      configure_defined_datastreams
    end  
  end

end