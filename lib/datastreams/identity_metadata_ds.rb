class IdentityMetadataDS < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  set_terminology do |t|
    t.root(:path=>"identityMetadata")
    t.objectId
    t.objectType :index_as => [:searchable, :facetable]
    t.objectLabel
    t.citationCreator
    t.sourceId
    t.otherId
    t.agreementId :index_as => [:searchable, :facetable]
    t.tag :index_as => [:searchable, :facetable]
    t.citationTitle
    t.objectCreator :index_as => [:searchable, :facetable]
    t.adminPolicy :index_as => [:searchable, :facetable]
  end
  
  define_template :value do |builder,name,value,attrs|
    builder.send(name.to_sym, value, attrs)
  end
  
  def self.xml_template
    Nokogiri::XML('<identityMetadata/>')
  end #self.xml_template
  
  def add_value(name, value, attrs={})
    add_child_node(ng_xml.root, :value, name, value, attrs)
  end
  
  def objectId
    self.find_by_terms(:objectId).text
  end
  
  def sourceId
    node = self.find_by_terms(:sourceId).first
    node ? [node['source'],node.text].join(':') : nil
  end
  
  def sourceId=(value)
    (source,val) = value.split(/:/,2)
    node = self.find_by_terms(:sourceId).first || ng_xml.root.add_child('<sourceId/>').first
    node['source'] = source
    node.content = val
  end

  def otherId(type = nil)
    result = self.find_by_terms(:otherId).to_a
    if type.nil?
      result.collect { |n| [n['name'],n.text].join(':') }
    else
      result.select { |n| n['name'] == type }.collect { |n| n.text }
    end
  end
  
  def to_solr(solr_doc=Hash.new, *args)
    super(solr_doc, *args)
    [self.sourceId, self.otherId].flatten.compact.each { |qid|
      (name,id) = qid.split(/:/,2)
      add_solr_value(solr_doc, "dor_id", id, :string, [:searchable])
      add_solr_value(solr_doc, "identifier", qid, :string, [:searchable])
      add_solr_value(solr_doc, "#{name}_id", id, :string, [:searchable])
    }
    
    self.find_by_terms(:tag).each { |tag|
      (top,rest) = tag.text.split(/:/,2)
      add_solr_value(solr_doc, "#{top.downcase.strip}_tag", rest.strip, :string, [:searchable, :facetable])
    }
    solr_doc
  end
end #class