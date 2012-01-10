require 'dor/base'
require 'datastreams/managed_nokogiri_ds'
require 'datastreams/content_metadata_ds'
require 'datastreams/ng_tidy'
require 'tmpdir'

module Dor
  
  class Item < Base
    
    has_metadata :name => "contentMetadata", :type => ContentMetadataDS, :label => 'Content Metadata'
    has_metadata :name => "descMetadata", :type => ActiveFedora::ManagedNokogiriDatastream, :label => 'Descriptive Metadata'
    has_metadata :name => "rightsMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Rights Metadata'
    has_metadata :name => "provenanceMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Provenance Metadata'
    has_metadata :name => "technicalMetadata", :type => ActiveFedora::ManagedNokogiriDatastream, :label => 'Technical Metadata'

    DESC_MD_FORMATS = {
      "http://www.tei-c.org/ns/1.0" => 'tei',
      "http://www.loc.gov/mods/v3" =>  'mods'
    }
    class CrosswalkError < Exception; end

    def admin_policy_object
      apo_ref = Array(self.rels_ext.relationships[:self]['hydra_isGovernedBy']).first
      if apo_ref.nil?
        return nil
      else
        apo_id = apo_ref.split(%r{/}).last
        if apo_id.empty?
          return nil
        else
          return Dor::AdminPolicyObject.load_instance(apo_id)
        end
      end
    end

    def milestones
      Dor::WorkflowService.get_milestones('dor',self.pid)
    end
    
    def fetch_descMetadata_datastream
      candidates = self.identity_metadata.otherIds.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      unless metadata_id.nil?
        return Dor::MetadataService.fetch(metadata_id.to_s)
      else
        return nil
      end
    end

    def build_contentMetadata_datastream(ds)
      path = Druid.new(self.pid).path(Dor::Config.stacks.local_workspace_root)
      if File.exists?(File.join(path, 'content_metadata.xml'))
        ds.label = 'Content Metadata'
        ds.ng_xml = Nokogiri::XML(File.read(File.join(path, 'content_metadata.xml')))
      end
    end
    
    def build_descMetadata_datastream(ds)
      content = fetch_descMetadata_datastream
      unless content.nil?
        ds.label = 'Descriptive Metadata'
        ds.ng_xml = Nokogiri::XML(content)
        ds.ng_xml.normalize_text!
      end
    end
    
    def build_rightsMetadata_datastream(ds)
      content_ds = self.admin_policy_object.datastreams['defaultObjectRights']
      ds.label = 'Rights Metadata'
      ds.ng_xml = content_ds.ng_xml.clone
    end

    def public_relationships
      include_elements = ['fedora:isMemberOf','fedora:isMemberOfCollection']
      rels_doc = Nokogiri::XML(self.datastreams['RELS-EXT'].content)
      rels_doc.xpath('/rdf:RDF/rdf:Description/*', { 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' }).each do |rel|
        unless include_elements.include?([rel.namespace.prefix,rel.name].join(':'))
          rel.next_sibling.remove if rel.next_sibling.content.strip.empty?
          rel.remove 
        end
      end
      rels_doc
    end
    
    def public_xml      
      pub = Nokogiri::XML("<publicObject/>").root
      pub['id'] = pid
      pub['published'] = Time.now.xmlschema
      pub.add_child(self.datastreams['identityMetadata'].ng_xml.root.clone)
      pub.add_child(self.datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(self.datastreams['rightsMetadata'].ng_xml.root.clone)
      rels = public_relationships.root
      pub.add_child(rels.clone) unless rels.nil? # TODO: Should never be nil in practice; working around an ActiveFedora quirk for testing
      pub.add_child(generate_dublin_core.root)
      Nokogiri::XML(pub.to_xml) { |x| x.noblanks }.to_xml { |config| config.no_declaration }
    end
    
    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #   Should not be used for the Fedora DC datastream
    # @raise [Exception] Raises an Exception if the generated DC is empty or has no children
    def generate_dublin_core
      format = self.metadata_format
      if format.nil?
        raise CrosswalkError, "Unknown descMetadata namespace: #{namespace.inspect}"
      end
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/#{format}2dc.xslt")) )
      dc_doc = xslt.transform(self.datastreams['descMetadata'].ng_xml)
      if(dc_doc.root.nil? || dc_doc.root.children.size == 0)
        raise "Dor::Item#generate_dublin_core produced incorrect xml:\n#{dc_doc.to_xml}"
      end
      dc_doc
    end
    
    def metadata_format
      desc_md = self.datastreams['descMetadata'].ng_xml
      return nil if desc_md.nil? or desc_md.root.nil? or desc_md.root.namespace.nil?
      DESC_MD_FORMATS[desc_md.root.namespace.href]
    end
    
    def publish_metadata
      rights = datastreams['rightsMetadata'].ng_xml
      if(rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world"))
        dc_xml = self.generate_dublin_core.to_xml {|config| config.no_declaration}
        DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['identityMetadata'].to_xml, 'identityMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['contentMetadata'].to_xml, 'contentMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['rightsMetadata'].to_xml, 'rightsMetadata')
        if self.metadata_format == 'mods'
          DigitalStacksService.transfer_to_document_store(pid, self.datastreams['descMetadata'].to_xml, 'mods')
        end
        DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
      end
    end

    def build_provenanceMetadata_datastream(workflow_id, event_text)
      ProvenanceMetadataService.add_provenance(self, workflow_id, event_text)
    end

    def build_technicalMetadata_datastream(ds)
      unless defined? ::JhoveService
        begin
          require 'jhove_service'
        rescue LoadError => e
          puts e.inspect
          raise "jhove-service dependency gem was not found.  Please add it to your Gemfile and run bundle install"
        end
      end
      begin
        content_dir = Druid.new(self.pid).path(Config.sdr.local_workspace_root)
        temp_dir = Dir.mktmpdir(self.pid)
        jhove_service = ::JhoveService.new(temp_dir)
        jhove_output_file = jhove_service.run_jhove(content_dir)
        tech_md_file = jhove_service.create_technical_metadata(jhove_output_file)
        ds.label = 'Technical Metadata'
        ds.ng_xml = Nokogiri::XML(IO.read(tech_md_file))
      ensure
        FileUtils.remove_entry_secure(temp_dir) if File.exist?(temp_dir)
      end
    end

    def shelve
      files = [] # doc.xpath("//file").select {|f| f['shelve'] == 'yes'}.map{|f| f['id']}
      self.datastreams['contentMetadata'].ng_xml.xpath('//file').each do |file|
        files << file['id'] if(file['shelve'].downcase == 'yes')
      end
      
      DigitalStacksService.shelve_to_stacks(pid, files)
    end

    def sdr_ingest_transfer(agreement_id)
      SdrIngestService.transfer(self,agreement_id)
    end

    def cleanup()
      CleanupService.cleanup(self)
    end

    def initiate_apo_workflow(name)
      wf_xml = admin_policy_object.datastreams['administrativeMetadata'].ng_xml.xpath(%{//workflow[@id="#{name}"]}).first.to_xml
      Dor::WorkflowService.create_workflow('dor',self.pid,name,wf_xml)
    end
    
    def workflows
      datastreams.keys.select { |k| k =~ /WF$/ }
    end
    
  end

  Base.register_type('item', Item)
end