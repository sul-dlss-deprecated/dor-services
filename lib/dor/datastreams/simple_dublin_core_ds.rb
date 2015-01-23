class SimpleDublinCoreDs < ActiveFedora::OmDatastream 
  
  set_terminology do |t|
    t.root(:path=>"dc", :xmlns=>"http://www.openarchives.org/OAI/2.0/oai_dc/", :schema=>"http://cosimo.stanford.edu/standards/oai_dc/v2/oai_dc.xsd", :namespace_prefix => 'oai_dc', :index_as => [:not_searchable])
    t.dc_title(:index_as=>[:searchable, :displayable, :facetable, :stored_searchable], :xmlns => "http://purl.org/dc/elements/1.1/", :namespace_prefix => 'dc')
    t.dc_creator(:index_as=>[:searchable, :displayable, :facetable, :stored_searchable], :xmlns => "http://purl.org/dc/elements/1.1/", :namespace_prefix => 'dc')
    t.dc_identifier(:index_as=>[:searchable, :displayable, :stored_searchable], :xmlns => "http://purl.org/dc/elements/1.1/", :namespace_prefix => 'dc')
  end
  
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.dc(:xmlns=>"http://www.openarchives.org/OAI/2.0/oai_dc/", 
        'xmlns:dc'=>'http://purl.org/dc/elements/1.1/') {
          xml['dc'].title
          xml['dc'].creator
          xml['dc'].identifier
      }   
    end

    return builder.doc
  end
  
  def to_solr(solr_doc=Hash.new, *args)
    # There are a whole bunch of namespace-related things that can go
    # wrong with this terminology. Until it's fixed in OM, ignore them all.
    begin
      doc = super solr_doc, *args

      add_solr_value(doc, 'dc_title', self.title.first, :string, [:sortable])
      add_solr_value(doc, 'dc_creator', self.creator.first, :string, [:sortable])
      
      identifiers = {}

      self.identifier.each { |i| ns, val = i.split(":"); identifiers[ns] ||= val }

      identifiers.each do |ns, val|
        add_solr_value(doc, "dc_identifier_#{ns}", val, :string, [:sortable])
      end

      return doc
    rescue 
      solr_doc
    end
  end
end
