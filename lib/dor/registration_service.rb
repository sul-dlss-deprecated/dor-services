require 'active_fedora'
require 'guid'
require 'xml_models/foxml'
require 'xml_models/identity_metadata/identity_metadata'

require 'dor/search_service'

module Dor
  
  class RegistrationService
    
    class << self
      def register_object(params = {})
        [:object_type, :label].each do |required_param|
          unless params[required_param]
            raise Dor::ParameterError, "#{required_param.inspect} must be specified in call to #{self.name}.register_object"
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
          existing_pid = SearchService.query_by_id(pid).first
          unless existing_pid.nil?
            raise Dor::DuplicateIdError.new(existing_pid), "An object with the PID #{pid} has already been registered."
          end
        else
          pid = Dor::SuriService.mint_id
        end

        if (other_ids.has_key?(:uuid) or other_ids.has_key?('uuid')) == false
          other_ids[:uuid] = Guid.new.to_s
        end
        
        idmd = IdentityMetadata.new

        unless source_id.empty?
          source_name = source_id.keys.first
          source_value = source_id[source_name]
          existing_pid = SearchService.query_by_id("#{source_name}:#{source_value}").first
          unless existing_pid.nil?
            raise Dor::DuplicateIdError.new(existing_pid), "An object with the source ID '#{source_name}:#{source_value}' has already been registered."
          end
          idmd.sourceId.source = source_name
          idmd.sourceId.value = source_value
        end
        
        idmd.objectId = pid
        idmd.objectCreators << 'dor'
        idmd.objectLabels << label
        idmd.objectTypes << object_type
        idmd.adminPolicy = admin_policy
        other_ids.each_pair { |name,value| idmd.add_identifier(name,value) }
        tags.each { |tag| idmd.add_tag(tag) }
    
        foxml = Foxml.new(pid, label, content_model, idmd.to_xml, parent)
        foxml.admin_policy_object = admin_policy
    
        repo = Fedora::Repository.new(Dor::Config[:fedora_url])
        http_response = repo.ingest(foxml.to_xml(:undent_datastreams => true))
        result = {
          :response => http_response,
          :pid => pid
        }
        return(result)
      end
    end
    
  end

end
