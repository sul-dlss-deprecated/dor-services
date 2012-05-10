module Dor
  module Itemizable
    extend ActiveSupport::Concern

    included do
      has_metadata :name => "contentMetadata", :type => Dor::ContentMetadataDS, :label => 'Content Metadata', :control_group => 'M'
    end
    
    def build_contentMetadata_datastream(ds)
      path = DruidTools::Druid.new(self.pid,Dor::Config.stacks.local_workspace_root).path('..')
      if File.exists?(File.join(path, 'content_metadata.xml'))
        ds.dsLabel = 'Content Metadata'
        ds.ng_xml = Nokogiri::XML(File.read(File.join(path, 'content_metadata.xml')))
        ds.content = ds.ng_xml.to_xml
      end
    end
    
  end
end