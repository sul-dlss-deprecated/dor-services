require 'dor/base'

module Dor
  
  class Item < Base
    
    has_metadata :name => "descMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "rightsMetadata", :type => ActiveFedora::NokogiriDatastream
    
  end
  
  def admin_policy_object
    apo_id = self.datastreams['RELS-EXT'].ng_xml.search('//hydra:isGovernedBy/@rdf:resource').first.value.split(%r{/}).last
    if apo_id.nil? or apo_id.empty?
      return nil
    else
      return Dor::AdminPolicyObject.load_instance(apo_id)
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
  
  def build_descMetadata_datastream(ds)
    content = fetch_descMetadata_datastream
    unless content.nil?
      ds.label = 'Descriptive Metadata'
      ds.ng_xml = Nokogiri::XML(content)
    end
  end

end