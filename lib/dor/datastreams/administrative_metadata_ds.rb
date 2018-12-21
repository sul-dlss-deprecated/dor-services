# frozen_string_literal: true

module Dor
  class AdministrativeMetadataDS < ActiveFedora::OmDatastream
    set_terminology do |t|
      t.root path: 'administrativeMetadata', index_as: [:not_searchable]
      t.metadata_format path: 'descMetadata/format'
      t.admin_metadata_format path: 'descMetadata/format', index_as: [:symbol]
      t.metadata_source path: 'descMetadata/source', index_as: [:symbol]
      t.descMetadata do
        t.source
        t.format
      end
      # Placeholders for existing defined stanzas to be fleshed out as needed
      t.contact index_as: [:not_searchable]
      t.rights index_as: [:not_searchable]
      t.relationships index_as: [:not_searchable]
      t.registration index_as: [:not_searchable] do
        t.agreementId
        t.itemTag
        t.workflow_id path: 'workflow/@id', index_as: [:symbol]
        t.default_collection path: 'collection/@id'
      end
      t.workflow path: 'registration/workflow'
      t.deposit index_as: [:not_searchable]

      t.accessioning index_as: [:not_searchable] do
        t.workflow_id path: 'workflow/@id', index_as: [:symbol]
      end

      t.preservation index_as: [:not_searchable]
      t.dissemination index_as: [:not_searchable] do
        t.harvester
        t.releaseDelayLimit
      end
      t.defaults do
        t.initiate_workflow path: 'initiateWorkflow' do
          t.lane path: { attribute: 'lane' }
        end
        t.shelving path: 'shelving' do
          t.path path: { attribute: 'path' }
        end
      end
    end

    define_template :default_collection do |xml|
      xml.administrativeMetadata do
        xml.registration do
          xml.collection(id: '')
        end
      end
    end

    define_template :agreementId do |xml|
      xml.administrativeMetadata do
        xml.registration do
          xml.agreementId
        end
      end
    end

    define_template :metadata_format do |xml|
      xml.descMetadata do
        xml.format
      end
    end

    define_template :metadata_source do |xml|
      xml.administrativeMetadata do
        xml.descMetadata do
          xml.source
        end
      end
    end

    define_template :registration do |xml|
      xml.administrativeMetadata do
        xml.registration do
          xml.workflow(id: '')
        end
      end
    end

    define_template :default_collection do |xml|
      xml.administrativeMetadata do
        xml.registration do
          xml.collection
        end
      end
    end

    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml.administrativeMetadata {}
      end.doc
    end

    #################################################################################
    # Convenience methods to get and set properties
    # Hides complexity/verbosity of OM TermOperators for simple, non-repeating values
    #################################################################################

    def default_workflow_lane=(lane)
      defaults.initiate_workflow.lane = lane
    end

    def default_workflow_lane
      defaults.initiate_workflow.lane.first
    end

    def default_shelving_path=(path)
      defaults.shelving.path = path
    end

    def default_shelving_path
      defaults.shelving.path.first
    end

    # get all collections listed for this APO, used during registration
    # @return [Array] array of pids
    def default_collections
      term_values(:registration, :default_collection)
    end

    # Add a collection to the listing of collections for items governed by this apo.
    # @param val [String] pid of the collection, ex. druid:ab123cd4567
    def add_default_collection(val)
      xml = ng_xml
      ng_xml_will_change!
      reg = xml.search('//administrativeMetadata/registration').first
      unless reg
        reg = Nokogiri::XML::Node.new('registration', xml)
        xml.search('/administrativeMetadata').first.add_child(reg)
      end
      node = Nokogiri::XML::Node.new('collection', xml)
      node['id'] = val
      reg.add_child(node)
    end

    def remove_default_collection(val)
      ng_xml_will_change!
      ng_xml.search('//administrativeMetadata/registration/collection[@id=\'' + val + '\']').remove
    end

    def metadata_source
      super.first
    end

    def metadata_source=(val)
      if descMetadata.nil?
        ng_xml_will_change!
        add_child_node(administrativeMetadata, :descMetadata)
      end
      update_values(%i[descMetadata source] => val)
    end

    # List of default workflows, used to provide choices at registration
    # @return [Array] and array of pids, ex ['druid:ab123cd4567']
    def default_workflows
      term_values(:registration, :workflow_id)
    end

    # set a single default workflow
    # @param wf [String] the name of the workflow, ex. 'digitizationWF'
    def default_workflow=(wf_name)
      raise ArgumentError, 'Must have a valid workflow for default' if wf_name.blank?

      xml = ng_xml
      ng_xml_will_change!
      nodes = xml.search('//registration/workflow')
      if nodes.first
        nodes.first['id'] = wf_name
      else
        nodes = xml.search('//registration')
        unless nodes.first
          reg_node = Nokogiri::XML::Node.new('registration', xml)
          xml.root.add_child(reg_node)
        end
        nodes = xml.search('//registration')
        wf_node = Nokogiri::XML::Node.new('workflow', xml)
        wf_node['id'] = wf_name
        nodes.first.add_child(wf_node)
      end
    end

    def desc_metadata_format
      metadata_format.first
    end

    def desc_metadata_format=(format)
      # create the node if it isnt there already
      unless metadata_format.first
        ng_xml_will_change!
        add_child_node(ng_xml.root, :metadata_format)
      end
      update_values([:metadata_format] => format)
    end

    def desc_metadata_source
      metadata_source.first
    end

    def desc_metadata_source=(_source)
      # create the node if it isnt there already
      unless metadata_source.first
        ng_xml_will_change!
        add_child_node(administrativeMetadata.ng_xml.root, :metadata_source)
      end
      update_values([:metadata_source] => format)
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
