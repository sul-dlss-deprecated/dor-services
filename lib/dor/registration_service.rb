require 'active_fedora'
require 'xml_models/foxml'
require 'xml_models/identity_metadata/identity_metadata'

module Dor
  
  class RegistrationService
    
    class << self
      def register_object(params = {})
        [:object_type, :content_model, :label].each do |required_param|
          unless params[required_param]
            raise Dor::ParameterError, ":#{required_param.to_s} must be specified in call to #{self.name}.register_object"
          end
        end

        object_type = params[:object_type]
        content_model = params[:content_model]
        admin_policy = params[:admin_policy]
        label = params[:label]
        source_id = params[:source_id] || {}
        other_ids = params[:other_ids] || {}
        tags = params[:tags] || []
        parent = params[:parent]
        pid = nil
        if params[:pid]
          pid = params[:pid]
          if self.query_by_id(pid).length > 0
            raise Dor::DuplicateIdError, "An object with the PID #{pid} has already been registered."
          end
        else
          pid = Dor::SuriService.mint_id
        end
        
        if self.query_by_id(source_id).length > 0
          raise Dor::DuplicateIdError, "An object with the source #{source_id.keys.first} and ID '#{source_id.values.first}' has already been registered."
        end
        
        other_ids.each_pair do |*id| 
          if self.query_by_id(id).length > 0
            raise Dor::DuplicateIdError, "An object with the #{id[0]} '#{id[1]}' has already been registered."
          end
        end
        
        idmd = IdentityMetadata.new
        idmd.objectTypes << object_type
        idmd.sourceId.source = source_id[:source]
        idmd.sourceId.value = source_id[:value]
        other_ids.each_pair { |name,value| idmd.add_identifier(name,value) }
        tags.each { |tag| idmd.add_tag(tag) }
    
        foxml = Foxml.new(pid, label, content_model, idmd.to_xml, parent)
        foxml.admin_policy_object = admin_policy
    
        http_response = Fedora::Repository.instance.ingest(foxml.to_xml)
        new_object = begin
          Dor::Base.load_instance(pid) 
        rescue ActiveFedora::ObjectNotFoundError
          nil
        end
        result = {
          :status => http_response.code,
          :message => http_response.message,
          :pid => pid,
          :object => new_object
        }
        return(result)
      end
      
      def query_by_id(id)
        if id.is_a?(Hash) # Single valued: { :google => 'STANFORD_0123456789' }
          id = id.collect { |*v| v.join(':') }.first
        elsif id.is_a?(Array) # Two values: [ 'google', 'STANFORD_0123456789' ]
          id = id.join(':')
        end
        
        solr = Solr::Connection.new(Dor::Config[:gsearch_solr_url])
        solr.query(%{PID:"#{id}" OR dor_id_field:"#{id}"}).collect { |hit| hit['PID'] }.flatten
      end
    end

  end

end
