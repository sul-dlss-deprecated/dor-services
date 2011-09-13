require 'dor/base'
require 'datastreams/content_metadata_ds'

module Dor
  
  class Item < Base
    
    has_metadata :name => "contentMetadata", :type => ContentMetadataDS
    has_metadata :name => "descMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "rightsMetadata", :type => ActiveFedora::NokogiriDatastream
    
    def admin_policy_object
      apo_ref = self.datastreams['RELS-EXT'].ng_xml.search('//hydra:isGovernedBy/@rdf:resource', Foxml::NAMESPACES).first
      if apo_ref.nil?
        return nil
      else
        apo_id = apo_ref.value.split(%r{/}).last
        if apo_id.empty?
          return nil
        else
          return Dor::AdminPolicyObject.load_instance(apo_id)
        end
      end
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
      end
    end
    
    def build_rightsMetadata_datastream(ds)
      content_ds = self.admin_policy_object.datastreams['defaultObjectRights']
      ds.label = 'Rights Metadata'
      ds.ng_xml = content_ds.ng_xml.clone
    end
    
    def public_xml      
      pub = Nokogiri::XML("<publicObject/>").root
      pub['id'] = pid
      pub.add_child(self.datastreams['identityMetadata'].ng_xml.root.clone)
      pub.add_child(self.datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(self.datastreams['rightsMetadata'].ng_xml.root.clone)
      pub.add_child(generate_dublin_core.root)
      Nokogiri::XML(pub.to_xml) { |x| x.noblanks }.to_xml { |config| config.no_declaration }
    end
    
    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    # Should not be used for the Fedora DC datastream
    def generate_dublin_core
      apo = self.admin_policy_object
      format = apo.nil? ? 'mods' : apo.datastreams['administrativeMetadata'].ng_xml.at('/administrativeMetadata/descMetadata/format').text.downcase
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/#{format}2dc.xslt")) )
      xslt.transform(self.datastreams['descMetadata'].ng_xml)
    end
    
    def publish_metadata
      DigitalStacksService.transfer_to_document_store(pid, self.datastreams['identityMetadata'].to_xml, 'identityMetadata')
      DigitalStacksService.transfer_to_document_store(pid, self.datastreams['contentMetadata'].to_xml, 'contentMetadata')
      DigitalStacksService.transfer_to_document_store(pid, self.datastreams['rightsMetadata'].to_xml, 'rightsMetadata')
      dc_xml = self.generate_dublin_core.to_xml {|config| config.no_declaration}
      DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
      DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
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
    
  end

end