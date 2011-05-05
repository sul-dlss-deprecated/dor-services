require 'active_fedora'
require 'datastreams/identity_metadata_ds'
require 'datastreams/simple_dublin_core_ds'
require 'datastreams/workflow_ds'
require 'dor/suri_service'

module Dor

  class Base < ::ActiveFedora::Base
    
    attr_reader :workflows

    has_metadata :name => "identityMetadata", :type => IdentityMetadataDS
    has_metadata :name => "descMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "rightsMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "technicalMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "DC", :type => SimpleDublinCoreDs
    has_metadata :name => "RELS-EXT", :type => ActiveFedora::NokogiriDatastream

    def initialize(attrs = {})
      unless attrs[:pid]
        attrs = attrs.merge!({:pid=>Dor::SuriService.mint_id})  
        @new_object=true
      else
        @new_object = attrs[:new_object] == false ? false : true
      end
      @inner_object = Fedora::FedoraObject.new(attrs)
      @datastreams = {}
      @workflows = {}
      configure_defined_datastreams
    end  

    def admin_policy_object
      apo_id = self.datastreams['RELS-EXT'].ng_xml.search('//hydra:isGovernedBy/@rdf:resource').first.value.split(%r{/}).last
      if apo_id.nil? or apo_id.empty?
        return nil
      else
        return Dor::AdminPolicyObject.load_instance(apo_id)
      end
    end
    
    def identity_metadata
      if self.datastreams.has_key?('identityMetadata')
        IdentityMetadata.from_xml(self.datastreams['identityMetadata'].content)
      else
        nil
      end
    end
  
    # Self-aware datastream builders
    def build_datastream(datastream, force = false)
      ds = datastreams[datastream]
      if force or (datastreams_in_fedora.has_key?(datastream) == false) or (ds.content.to_s.empty?)
        proc = "build_#{datastream}_datastream".to_sym
        content = self.send(proc, ds)
        ds.save
      end
      return ds
    end

    def build_descMetadata_datastream(ds)
      candidates = self.identity_metadata.otherIds
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      
      unless metadata_id.nil?
        content = Dor::MetadataService.fetch(metadata_id.to_s)
        unless content.nil?
          ds.label = 'Descriptive Metadata'
          ds.ng_xml = Nokogiri::XML(content)
        end
      end
    end

    # Serialization and indexing overrides
    def self.deserialize(doc)
      proto = super
      # Initialize workflow datastreams
      pid = doc.xpath('/foxml:digitalObject').first["PID"]
      doc.xpath("//foxml:datastream[foxml:datastreamVersion[@LABEL='Workflow']]").each do |node|
        name = node.attributes['ID'].text
        ds = WorkflowDs.new
        xml_content = Fedora::Repository.instance.fetch_custom(pid, "datastreams/#{name}/content")
        proto.workflows[name]=ds.class.from_xml(xml_content, ds)
      end
      return proto
    end
  
    def to_solr(solr_doc = Solr::Document.new, opts = {})
      solr_doc = super(solr_doc, opts)
      workflows.each_value do |ds|
        solr_doc = ds.to_solr(solr_doc) unless opts[:model_only]
      end
      return solr_doc
    end
  end
end