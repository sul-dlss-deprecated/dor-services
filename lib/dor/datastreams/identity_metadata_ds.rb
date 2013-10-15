module Dor
class IdentityMetadataDS < ActiveFedora::OmDatastream 
  include SolrDocHelper
  
  set_terminology do |t|
    t.root(:path=>"identityMetadata")
    t.objectId :index_as => [:symbol, :searchable]
    t.objectType :index_as => [:searchable, :facetable]
    t.objectLabel
    t.citationCreator
    t.sourceId
    t.otherId(:path => 'otherId') do
      t.name_(:path => { :attribute => 'name' })
    end
    t.agreementId :index_as => [:searchable, :facetable]
    t.tag :index_as => [:searchable, :facetable]
    t.citationTitle
    t.objectCreator :index_as => [:searchable, :facetable]
    t.adminPolicy :index_as => [:not_searchable]
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
    node = self.find_by_terms(:sourceId).first
    unless value.present?
      node.remove unless node.nil?
      nil
    else
      (source,val) = value.split(/:/,2)
      unless source.present? and value.present?
        raise ArgumentError, "Source ID must follow the format namespace:value"
      end
      node = ng_xml.root.add_child('<sourceId/>').first if node.nil?
      node['source'] = source
      node.content = val
      node
    end
  end
  def tags()
      result=[]
      self.ng_xml.search('//tag').each do |node|
        result << node.content
      end
      result
  end
  def otherId(type = nil)
    result = self.find_by_terms(:otherId).to_a
    if type.nil?
      result.collect { |n| [n['name'],n.text].join(':') }
    else
      result.select { |n| n['name'] == type }.collect { |n| n.text }
    end
  end

  def add_otherId(other_id)
    (name,val) = other_id.split(/:/,2)
    node = ng_xml.root.add_child('<otherId/>').first
    node['name'] = name
    node.content = val
    node
  end
  
  def to_solr(solr_doc=Hash.new, *args)
    super(solr_doc, *args)
    if digital_object.respond_to?(:profile)
      digital_object.profile.each_pair do |property,value|
        if property =~ /Date/
          add_solr_value(solr_doc, property.underscore,  Time.parse(value).utc.xmlschema, :date, [:searchable])
        else
          add_solr_value(solr_doc, property.underscore, value, property =~ /Date/ ? :date : :string, [:searchable])
        end
      end
    end
    if sourceId.present?
      (name,id) = sourceId.split(/:/,2)
      add_solr_value(solr_doc, "dor_id", id, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, "identifier", sourceId, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, "source_id", sourceId, :string, [:searchable, :facetable, :symbol])
    end
    otherId.compact.each { |qid|
      (name,id) = qid.split(/:/,2)
      add_solr_value(solr_doc, "dor_id", id, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, "identifier", qid, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, "#{name}_id", id, :string, [:searchable, :facetable])
    }
        
    self.find_by_terms(:tag).each { |tag|
      (top,rest) = tag.text.split(/:/,2)
      unless rest.nil?
        add_solr_value(solr_doc, "#{top.downcase.strip.gsub(/\s/,'_')}_tag", rest.strip, :string, [:searchable, :facetable])
      end
    }
    solr_doc
  end
end #class
end
