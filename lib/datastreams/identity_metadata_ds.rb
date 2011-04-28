class IdentityMetadataDS < ActiveFedora::NokogiriDatastream 
  
  set_terminology do |t|
    t.root(:path=>"identityMetadata", :xmlns => '')
    t.objectId(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )
    t.objectType(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.objectLabel(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.citationCreator(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.sourceId(:index_as=>[:searchable,  :displayable, :facetable, :sortable], :attributes=>{:type=>"source"},  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.otherId(:index_as=>[:searchable,  :displayable, :facetable, :sortable], :attributes=>{:type=>"name"},  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.agreementId(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.tag(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.citationTitle(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string, :namespace_prefix => nil )  
    t.objectCreator(:index_as=>[:searchable, :displayable, :facetable, :sortable], :required=>:true, :type=>:string, :namespace_prefix => nil )
    t.adminPolicy(:index_as=>[:searchable, :displayable, :facetable, :sortable], :required=>:true, :type=>:string, :namespace_prefix => nil )
  end
  
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.identityMetadata {
        xml.citationTitle
        xml.objectCreator
      }
    end
    return builder.doc
  end #self.xml_template
  
end #class