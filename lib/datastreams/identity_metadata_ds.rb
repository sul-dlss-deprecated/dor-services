class IdentityMetadataDS < ActiveFedora::NokogiriDatastream 

  set_terminology do |t|
    t.root(:path=>"identityMetadata", :xmlns => '')
    t.objectId :namespace_prefix => nil
    t.objectType :namespace_prefix => nil
    t.objectLabel :namespace_prefix => nil
    t.citationCreator :namespace_prefix => nil
    t.sourceId :namespace_prefix => nil
    t.otherId :namespace_prefix => nil
    t.agreementId :namespace_prefix => nil
    t.tag :namespace_prefix => nil
    t.citationTitle :namespace_prefix => nil
    t.objectCreator :namespace_prefix => nil
    t.adminPolicy :namespace_prefix => nil
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
    [node['source'],node.text].join(':')
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
  
end #class