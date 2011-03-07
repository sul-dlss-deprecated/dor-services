require 'active_fedora'
require 'guid'
require 'xml_models/foxml'
require 'xml_models/identity_metadata/identity_metadata'

module Dor
  
  class RegistrationService
    
    RISEARCH_TEMPLATE = "select $object from <#ri> where $object <dc:identifier> '%s'"
    
    class << self
      def register_object(params = {})
        [:object_type, :label].each do |required_param|
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

        if (other_ids.has_key?(:uuid) or other_ids.has_key?('uuid')) == false
          other_ids[:uuid] = Guid.new.to_s
        end
        
        source_name = source_id.keys.first
        source_value = source_id[source_name]
        if self.query_by_id("#{source_name}:#{source_value}").length > 0
          raise Dor::DuplicateIdError, "An object with the source ID '#{source_name}:#{source_value}' has already been registered."
        end
        
        idmd = IdentityMetadata.new
        idmd.objectId = pid
        idmd.objectCreators << 'dor'
        idmd.objectLabels << label
        idmd.objectTypes << object_type
        idmd.sourceId.source = source_name
        idmd.sourceId.value = source_value
        other_ids.each_pair { |name,value| idmd.add_identifier(name,value) }
        tags.each { |tag| idmd.add_tag(tag) }
    
        foxml = Foxml.new(pid, label, content_model, idmd.to_xml, parent)
        foxml.admin_policy_object = admin_policy
    
        http_response = Fedora::Repository.instance.ingest(foxml.to_xml(:undent_datastreams => true))
        result = {
          :response => http_response,
          :pid => pid
        }
        return(result)
      end
      
      def query_by_id(id)
        if id.is_a?(Hash) # Single valued: { :google => 'STANFORD_0123456789' }
          id = id.collect { |*v| v.join(':') }.first
        elsif id.is_a?(Array) # Two values: [ 'google', 'STANFORD_0123456789' ]
          id = id.join(':')
        end
        query_params = {
          :type => 'tuples',
          :lang => 'itql',
          :format => 'CSV',
          :limit => '1000',
          :query => (RISEARCH_TEMPLATE % id)
        }
        
        client = RestClient::Resource.new(
          Dor::Config[:fedora_url],
          :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Dor::Config[:fedora_cert_file])),
          :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Dor::Config[:fedora_key_file]), Dor::Config[:fedora_key_pass])
        )
        result = client['risearch'].post(query_params)
        result.split(/\n/)[1..-1].collect { |pid| pid.chomp.sub(/^info:fedora\//,'') }
      end
    end

  end

end
