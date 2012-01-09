require 'datastreams/content_metadata_ds'

module Dor
  module Publishable
    extend ActiveSupport::Concern
    include Identifiable
    include Governable
    include Describable

    included do
      has_metadata :name => "contentMetadata", :type => ContentMetadataDS, :label => 'Content Metadata'
      has_metadata :name => "rightsMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Rights Metadata'
    end
    
    def build_contentMetadata_datastream(ds)
      path = Druid.new(self.pid).path(Dor::Config.stacks.local_workspace_root)
      if File.exists?(File.join(path, 'content_metadata.xml'))
        ds.label = 'Content Metadata'
        ds.ng_xml = Nokogiri::XML(File.read(File.join(path, 'content_metadata.xml')))
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
      pub['published'] = Time.now.xmlschema
      pub.add_child(self.datastreams['identityMetadata'].ng_xml.root.clone)
      pub.add_child(self.datastreams['contentMetadata'].public_xml.root.clone)
      pub.add_child(self.datastreams['rightsMetadata'].ng_xml.root.clone)
      pub.add_child(generate_dublin_core.root)
      Nokogiri::XML(pub.to_xml) { |x| x.noblanks }.to_xml { |config| config.no_declaration }
    end
    
    def publish_metadata
      rights = datastreams['rightsMetadata'].ng_xml
      if(rights.at_xpath("//rightsMetadata/access[@type='discover']/machine/world"))
        dc_xml = self.generate_dublin_core.to_xml {|config| config.no_declaration}
        DigitalStacksService.transfer_to_document_store(pid, dc_xml, 'dc')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['identityMetadata'].to_xml, 'identityMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['contentMetadata'].to_xml, 'contentMetadata')
        DigitalStacksService.transfer_to_document_store(pid, self.datastreams['rightsMetadata'].to_xml, 'rightsMetadata')
        DigitalStacksService.transfer_to_document_store(pid, public_xml, 'public')
        if self.metadata_format == 'mods'
          DigitalStacksService.transfer_to_document_store(pid, self.datastreams['descMetadata'].to_xml, 'mods')
        end
      end
    end

  end
end