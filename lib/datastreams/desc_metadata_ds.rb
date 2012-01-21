class DescMetadataDS < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  # This is a temporary stand-in for a more full-feature MODS implementation. For
  # now, it's ONLY used for indexing.

  set_terminology do |t|
    t.root :path => 'mods', :xmlns => 'http://www.loc.gov/mods/v3', :namespace_prefix => 'mods', :index_as => [:not_searchable]
    t.originInfo :namespace_prefix => 'mods', :index_as => [:not_searchable] do
      t.publisher :namespace_prefix => 'mods', :index_as => [:searchable, :displayable]
      t.place :namespace_prefix => 'mods', :index_as => [:not_searchable] do
        t.placeTerm :attributes => {:type => 'text'}, :namespace_prefix => 'mods', :index_as => [:searchable, :displayable]
      end
    end
    t.coordinates :namespace_prefix => 'mods', :index_as => [:searchable]
    t.extent :namespace_prefix => 'mods', :index_as => [:searchable]
    t.scale :namespace_prefix => 'mods', :index_as => [:searchable]
    t.topic :namespace_prefix => 'mods', :index_as => [:searchable]
  end

  def to_solr(solr_doc=Hash.new,*args)
    super(solr_doc,*args)
    ng_xml.xpath('/mods:mods/mods:identifier').each do |node|
      field_name = node['displayLabel'].downcase.gsub(/\s+/,'_')
      add_solr_value(solr_doc, "mods_identifier", "#{node['displayLabel']}:#{node.text}", :string, [:searchable, :displayable])
      add_solr_value(solr_doc, "mods_#{field_name}_identifier", node.text, :string, [:searchable, :displayable])
    end
    
    ng_xml.xpath('/mods:mods/mods:titleInfo').each do |node|
      add_solr_value(solr_doc, "mods_title", extract_title_info(node), :string, [:searchable, :displayable])
    end
    
    ng_xml.xpath('/mods:mods/mods:name').each do |node|
      add_solr_value(solr_doc, "mods_name", extract_name(node), :string, [:searchable, :displayable])
      node.xpath('mods:role/mods:roleTerm[@type="text"]').each do |role|
        add_solr_value(solr_doc, "mods_role", role.text, :string, [:searchable, :displayable])
      end
    end
    
    ng_xml.xpath('/mods:*[contains(local-name(),"date") or contains(local-name(), "Date")]').each do |date|
      field_name = node.name.downcase.gsub(/\s+/,'_')
      add_solr_value(solr_doc, "mods_#{field_name}", node.text.gsub(/\s+/," ").strip, :string, [:searchable, :displayable])
    end
    solr_doc
  end
  
  def extract_title_info(node)
    result = ''
    (v = node.at_xpath('mods:nonSort')) and result += "#{v.text} "
    (v = node.at_xpath('mods:title')) and result += v.text
    (v = node.at_xpath('mods:subTitle')) and result += ": #{v.text}"
    (v = node.at_xpath('mods:partNumber')) and result += ". #{v.text}"
    (v = node.at_xpath('mods:partName')) and result += ". #{v.text}"
    result.gsub(/\s+/," ").strip
  end
  
  def extract_name(node)
    result = ''
    node.xpath('mods:namePart[not(@type)]').each { |v| result += "#{v.text} "}
    (v = node.at_xpath('mods:namePart[@type="family"]')) and result += v.text
    (v = node.at_xpath('mods:namePart[@type="given"]')) and result += ", #{v.text}"
    (v = node.at_xpath('mods:namePart[@type="date"]')) and result += ", #{v.text}"
    (v = node.at_xpath('mods:displayForm')) and result += " (#{v.text})"
    node.xpath('mods:role[mods:roleTerm[@type="text"]!="creator"]').each { |v| result += " (#{v.text})"}
    result.gsub(/\s+/," ").strip
  end
end
