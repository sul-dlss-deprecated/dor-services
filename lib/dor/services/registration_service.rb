# frozen_string_literal: true

require 'uuidtools'

module Dor
  class RegistrationService
    class << self
      # @TODO: Why isn't all this logic in, for example, Dor::Item.create? or Dor::Base.create? or Dor::Creatable.create?
      # @TODO: these duplicate checks could be combined into 1 query

      # @param [String] pid an ID to check, if desired.  If not passed (or nil), a new ID is minted
      # @return [String] a pid you can use immidately, either freshly minted or your checked value
      # @raise [Dor::DuplicateIdError]
      def unduplicated_pid(pid = nil)
        return Dor::SuriService.mint_id unless pid

        existing_pid = SearchService.query_by_id(pid).first
        raise Dor::DuplicateIdError.new(existing_pid), "An object with the PID #{pid} has already been registered." unless existing_pid.nil?

        pid
      end

      # @param [String] source_id_string a fully qualified source:val or empty string
      # @return [String] the same qualified source:id for immediate use
      # @raise [Dor::DuplicateIdError]
      def check_source_id(source_id_string)
        return '' if source_id_string == ''
        unless SearchService.query_by_id(source_id_string.to_s).first.nil?
          raise Dor::DuplicateIdError.new(source_id_string), "An object with the source ID '#{source_id_string}' has already been registered."
        end

        source_id_string
      end

      # @param [Hash{Symbol => various}] params
      # @option params [String] :object_type required
      # @option params [String] :label required
      # @option params [String] :admin_policy required
      # @option params [String] :metadata_source
      # @option params [String] :rights
      # @option params [String] :collection
      # @option params [Hash{String => String}] :source_id Primary ID from another system, max one key/value pair!
      # @option params [Hash] :other_ids including :uuid if known
      # @option params [String] :pid Fully qualified PID if you don't want one generated for you
      # @option params [Integer] :workflow_priority]
      # @option params [Array<String>] :seed_datastream datastream_names
      # @option params [Array<String>] :initiate_workflow workflow_ids
      # @option params [Array] :tags
      def register_object(params = {})
        %i[object_type label].each do |required_param|
          raise Dor::ParameterError, "#{required_param.inspect} must be specified in call to #{name}.register_object" unless params[required_param]
        end
        metadata_source = params[:metadata_source]
        raise Dor::ParameterError, "label cannot be empty to call #{name}.register_object" if params[:label].length < 1 && %w[label none].include?(metadata_source)

        object_type = params[:object_type]
        item_class = Dor.registered_classes[object_type]
        raise Dor::ParameterError, "Unknown item type: '#{object_type}'" if item_class.nil?

        # content_model = params[:content_model]
        # parent        = params[:parent]
        label         = params[:label]
        source_id     = params[:source_id] || {}
        other_ids     = params[:other_ids] || {}
        tags          = params[:tags] || []
        collection    = params[:collection]

        # Check for sourceId conflict *before* potentially minting PID
        source_id_string = check_source_id [source_id.keys.first, source_id[source_id.keys.first]].compact.join(':')
        pid = unduplicated_pid(params[:pid])

        raise ArgumentError, ":source_id Hash can contain at most 1 pair: recieved #{source_id.size}" if source_id.size > 1

        rights = nil
        if params[:rights]
          rights = params[:rights]
          raise Dor::ParameterError, "Unknown rights setting '#{rights}' when calling #{name}.register_object" unless rights == 'default' || RightsMetadataDS.valid_rights_type?(rights)
        end

        other_ids[:uuid] = UUIDTools::UUID.timestamp_create.to_s if (other_ids.key?(:uuid) || other_ids.key?('uuid')) == false
        apo_object = Dor.find(params[:admin_policy])
        new_item = item_class.new(pid: pid)
        new_item.label = label.length > 254 ? label[0, 254] : label
        idmd = new_item.identityMetadata
        idmd.sourceId = source_id_string
        idmd.add_value(:objectId, pid)
        idmd.add_value(:objectCreator, 'DOR')
        idmd.add_value(:objectLabel, label)
        idmd.add_value(:objectType, object_type)
        other_ids.each_pair { |name, value| idmd.add_otherId("#{name}:#{value}") }
        tags.each { |tag| idmd.add_value(:tag, tag) }
        new_item.admin_policy_object = apo_object

        apo_object.administrativeMetadata.ng_xml.xpath('/administrativeMetadata/relationships/*').each do |rel|
          short_predicate = ActiveFedora::RelsExtDatastream.short_predicate rel.namespace.href + rel.name
          if short_predicate.nil?
            ix = 0
            ix += 1 while ActiveFedora::Predicates.predicate_mappings[rel.namespace.href].key?(short_predicate = :"extra_predicate_#{ix}")
            ActiveFedora::Predicates.predicate_mappings[rel.namespace.href][short_predicate] = rel.name
          end
          new_item.add_relationship short_predicate, rel['rdf:resource']
        end
        new_item.add_collection(collection) if collection
        if rights && %w(item collection).include?(object_type)
          rights_xml = apo_object.defaultObjectRights.ng_xml
          new_item.datastreams['rightsMetadata'].content = rights_xml.to_s
          new_item.set_read_rights(rights) unless rights == 'default' # already defaulted to default!
        end
        # create basic mods from the label
        if metadata_source == 'label'
          ds = new_item.build_datastream('descMetadata')
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.mods(Dor::DescMetadataDS::MODS_HEADER_CONFIG) do
              xml.titleInfo do
                xml.title label
              end
            end
          end
          ds.content = builder.to_xml
        end

        workflow_priority = params[:workflow_priority] ? params[:workflow_priority].to_i : 0

        Array(params[:seed_datastream]).each { |datastream_name| new_item.build_datastream(datastream_name) }
        Array(params[:initiate_workflow]).each { |workflow_id| new_item.create_workflow(workflow_id, !new_item.new_record?, workflow_priority) }

        new_item.class.ancestors.select { |x| x.respond_to?(:to_class_uri) && x != ActiveFedora::Base }.each do |parent_class|
          new_item.add_relationship(:has_model, parent_class.to_class_uri)
        end

        new_item.save
        new_item
      end

      # @param [Hash] params
      # @see register_object similar but different
      def create_from_request(params)
        other_ids = Array(params[:other_id]).map do |id|
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
          pid: params[:pid],
          admin_policy: params[:admin_policy],
          content_model: params[:model],
          label: params[:label],
          object_type: params[:object_type],
          other_ids: ids_to_hash(other_ids),
          parent: params[:parent],
          source_id: ids_to_hash(params[:source_id]),
          tags: params[:tag] || [],
          seed_datastream: params[:seed_datastream],
          initiate_workflow: Array(params[:initiate_workflow]) + Array(params[:workflow_id]),
          rights: params[:rights],
          metadata_source: params[:metadata_source],
          collection: params[:collection],
          workflow_priority: params[:workflow_priority]
        }
        dor_params.delete_if { |_k, v| v.nil? }

        dor_obj = register_object(dor_params)
        pid = dor_obj.pid
        location = URI.parse(Dor::Config.fedora.safeurl.sub(/\/*$/, '/')).merge("objects/#{pid}").to_s
        dor_params.dup.merge(location: location, pid: pid)
      end

      private

      def ids_to_hash(ids)
        return nil if ids.nil?

        Hash[Array(ids).map { |id| id.split(':', 2) }]
      end
    end
  end
end
