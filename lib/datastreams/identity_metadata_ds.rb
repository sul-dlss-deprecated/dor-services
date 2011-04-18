class IdentityMetadataDS < ActiveFedora::NokogiriDatastream 
  
  set_terminology do |t|
    t.root(:path=>"identityMetadata",  :xmlns=>"http://yourmediashelf.com/schemas/hydra-dataset/v0" )
    t.objectId(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.objectType(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.objectLabel(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.citationCreator(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.sourceId(:index_as=>[:searchable,  :displayable, :facetable, :sortable], :attributes=>{:type=>"source"},  :required=>:true, :type=>:string )  
    t.otherId(:index_as=>[:searchable,  :displayable, :facetable, :sortable], :attributes=>{:type=>"name"},  :required=>:true, :type=>:string )  
    t.agreementId(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.tag(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.agreementId(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.citationTitle(:index_as=>[:searchable, :displayable, :facetable, :sortable],  :required=>:true, :type=>:string )  
    t.objectCreator(:index_as=>[:searchable, :displayable, :facetable, :sortable], :required=>:true, :type=>:string)
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