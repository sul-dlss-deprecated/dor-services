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
    
    def clear_diff_cache
      diff_path = File.join(DruidTools::Druid.new(self.pid,Dor::Config.stacks.local_workspace_root).temp_dir,"cm_inv_diff.*")
      Dir[diff_path].each { |f| File.unlink(f) if File.exists?(f) }
    end
    
    def get_content_diff(subset='all', version=nil)
      basename = version.nil? ? 'cm_inv_diff.xml' : "'cm_inv_diff.#{version}.xml'"
      diff_path = File.join(DruidTools::Druid.new(self.pid,Dor::Config.stacks.local_workspace_root).temp_dir,basename)
      if File.exists? diff_path
        File.read(diff_path)
      else
        sdr_client = Dor::Config.sdr.rest_client
        current_content = self.datastreams['contentMetadata'].content
        qs = [['subset',subset],['version',version]].select { |k,v| v.present? }.collect { |a| a.join('=') }.join('&')
        url = "objects/#{self.pid}/cm-inv-diff?#{qs}"
        puts sdr_client[url].to_s
        response = sdr_client[url].post(current_content, :content_type => 'application/xml')
        File.open(diff_path,'w') { |f| f.write(response) }
        response
      end
    end
    
  end
end