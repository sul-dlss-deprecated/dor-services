module Dor
class IdentityMetadataDS < ActiveFedora::OmDatastream 
  include SolrDocHelper
  
  set_terminology do |t|
    t.root(:path=>"identityMetadata")
    t.objectId :index_as => [:symbol]
    t.objectType :index_as => [:symbol]
    t.objectLabel
    t.citationCreator
    t.sourceId
    t.otherId(:path => 'otherId') do
      t.name_(:path => { :attribute => 'name' })
    end
    t.agreementId :index_as => [:stored_searchable, :symbol]
    t.tag :index_as => [:symbol]
    t.citationTitle
    t.objectCreator :index_as => [:stored_searchable, :symbol]
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
      digital_object.profile.each_pair do |property, value|
        add_solr_value(solr_doc, property.underscore, value, (property =~ /Date/ ? :date : :symbol), [:stored_searchable])
      end
    end

    if sourceId.present?
      (name, id) = sourceId.split(/:/, 2)
      add_solr_value(solr_doc, "dor_id", id, :symbol, [:stored_searchable])
      add_solr_value(solr_doc, "identifier", sourceId, :symbol, [:stored_searchable])
      add_solr_value(solr_doc, "source_id", sourceId, :symbol, [])
    end
    otherId.compact.each { |qid|
      # this section will solrize barcode and catkey, which live in otherId
      (name, id) = qid.split(/:/, 2)
      add_solr_value(solr_doc, "dor_id", id, :symbol, [:stored_searchable])
      add_solr_value(solr_doc, "identifier", qid, :symbol, [:stored_searchable])
      add_solr_value(solr_doc, "#{name}_id", id, :symbol, [])
    }
    
    # do some stuff to make tags in general and project tags specifically more easily searchable and facetable
    self.find_by_terms(:tag).each { |tag|
      (prefix, rest) = tag.text.split(/:/, 2)
      prefix = prefix.downcase.strip.gsub(/\s/,'_')
      unless rest.nil?
        # this part will index a value in a field specific to the tag, e.g. registered_by_tag_*, 
        # book_tag_*, project_tag_*, remediated_by_tag_*, etc.  project_tag_* and registered_by_tag_*
        # definitley get used, but most don't.  we can limit the prefixes that get solrized if things 
        # get out of hand.
        add_solr_value(solr_doc, "#{prefix}_tag", rest.strip, :symbol, [])
      end

      # solrize each possible prefix for the tag, inclusive of the full tag.
      # e.g., for a tag such as "A : B : C", this will solrize to an _ssim field 
      # that contains ["A",  "A : B",  "A : B : C"].
      tag_parts = tag.text.split(/:/)
      progressive_tag_prefix = ''
      tag_parts.each_with_index do |part, index|
        progressive_tag_prefix += " : " if index > 0
        progressive_tag_prefix += part.strip
        add_solr_value(solr_doc, "exploded_tag", progressive_tag_prefix, :symbol, [])
      end
    }

    return solr_doc
  end
end #class
end
