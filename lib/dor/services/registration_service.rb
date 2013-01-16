require 'uuidtools'

module Dor
  
  class RegistrationService
    
    class << self
      def register_object(params = {})
        Dor.ensure_models_loaded!
        [:object_type, :label, :source_id].each do |required_param|
          raise Dor::ParameterError, "#{required_param.inspect} must be specified in call to #{self.name}.register_object" unless params[required_param]
        end
        metadata_source=params[:metadata_source]
        if params[:label].length<1 and (metadata_source=='label' || metadata_source=='none')
          raise Dor::ParameterError, "label cannot be empty to call #{self.name}.register_object"
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
        collection = params[:collection]
        pid = nil
        metadata_source=params[:metadata_source]
        if params[:pid]
          pid = params[:pid]
          existing_pid = SearchService.query_by_id(pid).first
          unless existing_pid.nil?
            raise Dor::DuplicateIdError.new(existing_pid), "An object with the PID #{pid} has already been registered."
          end
        else
          pid = Dor::SuriService.mint_id
        end
        
        rights=nil
        if params[:rights]
          rights=params[:rights]
          if not ['world','stanford','dark','default','none'].include? rights
            raise Dor::ParameterError,"Unknown rights setting" + rights + "when calling #{self.name}.register_object"
          end
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
        short_label=label
        if label.length>254
          short_label=label[0,254]
        end
        
        apo_object = Dor.find(admin_policy, :lightweight => true)
        adm_xml = apo_object.administrativeMetadata.ng_xml
        
        new_item = item_class.new(:pid => pid)
        new_item.label = short_label
        idmd = new_item.identityMetadata
        idmd.sourceId = source_id_string
        idmd.add_value(:objectId, pid)
        idmd.add_value(:objectCreator, 'DOR')
        idmd.add_value(:objectLabel, label)
        idmd.add_value(:objectType, object_type)
        idmd.add_value(:adminPolicy, admin_policy)
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
          new_item.add_relationship short_predicate, rel['rdf:resource']
        end
        if collection
          new_item.add_collection(collection)
        end
        if(rights)
          rights_xml=apo_object.defaultObjectRights.ng_xml
          if rights=='world'
            rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
              node.children.remove
              machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
              world_node=Nokogiri::XML::Node.new('world',rights_xml)
              node.add_child(machine_node)
              machine_node.add_child(world_node)
            end 
          end
          if rights=='stanford'
            rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
              node.children.remove
              machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
              group_node=Nokogiri::XML::Node.new('group',rights_xml)
              group_node.content="Stanford"
              node.add_child(machine_node)
              machine_node.add_child(group_node)
              
            end
          end
          if rights=='none'
            rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
              node.children.remove
              machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
              none_node=Nokogiri::XML::Node.new('none',rights_xml)
              node.add_child(machine_node)
              machine_node.add_child(none_node)
            end
          end
          if rights=='dark'
            rights_xml.search('//rightsMetadata/access[@type=\'read\']').each do |node|
              node.children.remove
              machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
              none_node=Nokogiri::XML::Node.new('none',rights_xml)
              node.add_child(machine_node)
              machine_node.add_child(none_node)
            end
            #also replace the discovery rights with <machine><none/>
            rights_xml.search('//rightsMetadata/access[@type=\'discover\']').each do |node|
              node.children.remove
              machine_node=Nokogiri::XML::Node.new('machine',rights_xml)
              none_node=Nokogiri::XML::Node.new('none',rights_xml)
              node.add_child(machine_node)
              machine_node.add_child(none_node)
            end
          end
          
          new_item.datastreams['rightsMetadata'].content=rights_xml.to_s
        end
        #create basic mods from the label
        if(metadata_source=='label')
          ds=new_item.build_datastream('descMetadata');
          builder = Nokogiri::XML::Builder.new { |xml|
            xml.mods( 'xmlns' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',:version => '3.3', "xsi:schemaLocation" => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd'){
              xml.titleInfo{
                xml.title label
              }
            }
          }
      
      ds.content=builder.to_xml
         
      end
        
        
        Array(params[:seed_datastream]).each { |datastream_name| new_item.build_datastream(datastream_name) }
        Array(params[:initiate_workflow]).each { |workflow_id| new_item.initialize_workflow(workflow_id, 'dor', !new_item.new_object?)}

        new_item.assert_content_model
        new_item.save
        begin
          new_item.update_index if ::ENABLE_SOLR_UPDATES
        rescue StandardError => e
          Dor.logger.warn "Dor::RegistrationService.register_object failed to update solr index for #{new_item.pid}: #<#{e.class.name}: #{e.message}>"
        end
        return(new_item)
      end
      
      def create_from_request(params)
        other_ids = Array(params[:other_id]).collect do |id|
          if id =~ /^symphony:(.+)$/
            "#{$1.length < 14 ? 'catkey' : 'barcode'}:#{$1}"
          else
            id
          end
        end
    
        if params[:label] == ':auto'
          params.delete(:label)
          params.delete('label')
          metadata_id = Dor::MetadataService.resolvable(other_ids).first
          params[:label] = Dor::MetadataService.label_for(metadata_id)
        end
          
        dor_params = {
          :pid                => params[:pid],
          :admin_policy       => params[:admin_policy],
          :content_model      => params[:model],
          :label              => params[:label],
          :object_type        => params[:object_type],
          :other_ids          => ids_to_hash(other_ids),
          :parent             => params[:parent],
          :source_id          => ids_to_hash(params[:source_id]),
          :tags               => params[:tag] || [],
          :seed_datastream    => params[:seed_datastream],
          :initiate_workflow  => Array(params[:initiate_workflow]) + Array(params[:workflow_id]),
          :rights             => params[:rights],
          :metadata_source    => params[:metadata_source],
          :collection         => params[:collection]
        }
        dor_params.delete_if { |k,v| v.nil? }
    
        dor_obj = self.register_object(dor_params)
        pid = dor_obj.pid
        location = URI.parse(Dor::Config.fedora.safeurl.sub(/\/*$/,'/')).merge("objects/#{pid}").to_s
        reg_response = dor_params.dup.merge({ :location => location, :pid => pid })
      end
      
      private
      def ids_to_hash(ids)
        if ids.nil?
          nil
        else
          Hash[Array(ids).collect { |id| id.split(/:/) }]
        end
      end
    end
    
  end

end
