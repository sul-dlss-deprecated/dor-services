require 'uuidtools'

module Dor
  
  class RegistrationService
    
    class << self
      def register_object(params = {})
        [:object_type, :label].each do |required_param|
          raise Dor::ParameterError, "#{required_param.inspect} must be specified in call to #{self.name}.register_object" unless params[required_param]
        end
        object_type = params[:object_type]        
        item_class = Dor.registered_classes[object_type]
        raise Dor::ParameterError, "Unknown item type: '#{object_type}'" if item_class.nil?
        
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

        source_id_string = [source_id.keys.first,source_id[source_id.keys.first]].compact.join(':')
        unless source_id.empty?
          existing_pid = SearchService.query_by_id("#{source_id_string}").first
          unless existing_pid.nil?
            raise Dor::DuplicateIdError.new(existing_pid), "An object with the source ID '#{source_id_string}' has already been registered."
          end
        end

        if (other_ids.has_key?(:uuid) or other_ids.has_key?('uuid')) == false
          other_ids[:uuid] = UUIDTools::UUID.timestamp_create.to_s
        end

        apo_object = Dor.find(admin_policy, :lightweight => true)
        adm_xml = apo_object.administrativeMetadata.ng_xml
        agreement_id = adm_xml.at('/administrativeMetadata/registration/agreementId/text()').to_s
        
        new_item = item_class.new(:pid => pid)
        new_item.label = label
        idmd = new_item.identityMetadata
        idmd.sourceId = source_id_string
        idmd.add_value(:objectId, pid)
        idmd.add_value(:objectCreator, 'DOR')
        idmd.add_value(:objectLabel, label)
        idmd.add_value(:objectType, object_type)
        idmd.add_value(:adminPolicy, admin_policy)
        idmd.add_value(:agreementId, agreement_id) if agreement_id.present?
        other_ids.each_pair { |name,value| idmd.add_otherId("#{name}:#{value}") }
        tags.each { |tag| idmd.add_value(:tag, tag) }
        new_item.admin_policy_object_append apo_object
        
        adm_xml.xpath('/administrativeMetadata/relationships/*').each do |rel|
          short_predicate = ActiveFedora::RelsExtDatastream.short_predicate rel.namespace.href+rel.name
          if short_predicate.nil?
            ix = 0
            ix += 1 while ActiveFedora::Predicates.predicate_mappings[rel.namespace.href].has_key?(short_predicate = :"extra_predicate_#{ix}")
            ActiveFedora::Predicates.predicate_mappings[rel.namespace.href][short_predicate] = rel.name
          end
          new_item.add_relationship short_predicate, rel['resource']
        end

        Array(params[:seed_datastream]).each { |datastream_name| new_item.build_datastream(datastream_name) }
        Array(params[:initiate_workflow]).each { |workflow_id| new_item.initiate_apo_workflow(workflow_id) }

        new_item.save
        Dor::SearchService.solr.add new_item.to_solr
        return(new_item)
      end
    end
    
  end

end
