require 'active_fedora'
require 'dor/suri_service'
require 'xml_models/identity_metadata/identity_metadata'
require 'xml_models/foxml'

module Dor

  class Base < ActiveFedora::Base
    
    class << self
      def register_object(object_type, content_model, admin_policy, label, agreement_id, source_id = {}, other_ids = {}, tags = [])
        pid = Dor::SuriService.mint_id

        idmd = IdentityMetadata.new
        idmd.objectTypes << object_type
        idmd.adminPolicyObjects << admin_policy
        idmd.agreementIds << agreement_id
        idmd.sourceId.source = source_id[:source]
        idmd.sourceId.value = source_id[:value]
        other_ids.each_pair { |name,value| idmd.add_identifier(name,value) }
        tags.each { |tag| idmd.add_tag(tag) }
        
        foxml = Foxml.new(pid, label, content_model, idmd.to_xml)
      end
      
      private
      # Turn ['key1:value1','key2:value2'] into { 'key1' => 'value1', 'key2', 'value2' }
      def hashify_ids(ids)
        if ids.nil?
          return {}
        elsif ids.is_a?(Hash)
          return ids
        else
          return Hash[ids.collect { |id| id.split(/:/,2) }]
        end
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