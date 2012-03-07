module Dor
class DescMetadataDS < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  # This is a temporary stand-in for a more full-feature MODS implementation. For
  # now, it's ONLY used for indexing.

  MODS_NS = 'http://www.loc.gov/mods/v3'
  set_terminology do |t|
    t.root :path => 'mods', :xmlns => MODS_NS, :index_as => [:not_searchable]
    t.originInfo :index_as => [:not_searchable] do
      t.publisher :index_as => [:searchable, :displayable]
      t.place :index_as => [:not_searchable] do
        t.placeTerm :attributes => {:type => 'text'}, :index_as => [:searchable, :displayable]
      end
    end
    t.coordinates :index_as => [:searchable]
    t.extent :index_as => [:searchable]
    t.scale :index_as => [:searchable]
    t.topic :index_as => [:searchable]
  end

  def to_solr(solr_doc=Hash.new, *args)
    super(solr_doc,*args)
    ns = { 'mods' => MODS_NS }
    ng_xml.xpath('/mods:mods/mods:identifier',ns).each do |node|
      field_name = node['displayLabel'].to_s.downcase.gsub(/\s+/,'_')
      add_solr_value(solr_doc, "mods_identifier", "#{node['displayLabel']}:#{node.text}", :string, [:searchable, :displayable])
      add_solr_value(solr_doc, "mods_#{field_name}_identifier", node.text, :string, [:searchable, :displayable])
    end
    
    ng_xml.xpath('/mods:mods/mods:titleInfo',ns).each do |node|
      add_solr_value(solr_doc, "mods_title", extract_title_info(node), :string, [:searchable, :displayable])
    end
    
    ng_xml.xpath('/mods:mods/mods:name',ns).each do |node|
      add_solr_value(solr_doc, "mods_name", extract_name(node), :string, [:searchable, :displayable])
      node.xpath('mods:role/mods:roleTerm[@type="text"]',ns).each do |role|
        add_solr_value(solr_doc, "mods_role", role.text, :string, [:searchable, :displayable])
      end
    end
    
    ng_xml.xpath('/mods:*[contains(local-name(),"date") or contains(local-name(), "Date")]',ns).each do |date|
      field_name = node.name.downcase.gsub(/\s+/,'_')
      add_solr_value(solr_doc, "mods_#{field_name}", node.text.gsub(/\s+/," ").strip, :string, [:searchable, :displayable])
    end
    solr_doc
  end
  
  def extract_title_info(node)
    result = ''
    ns = { 'mods' => MODS_NS }
    (v = node.at_xpath('mods:nonSort',ns)) and result += "#{v.text} "
    (v = node.at_xpath('mods:title',ns)) and result += v.text
    (v = node.at_xpath('mods:subTitle',ns)) and result += ": #{v.text}"
    (v = node.at_xpath('mods:partNumber',ns)) and result += ". #{v.text}"
    (v = node.at_xpath('mods:partName',ns)) and result += ". #{v.text}"
    result.gsub(/\s+/," ").strip
  end
  
  def extract_name(node)
    result = ''
    ns = { 'mods' => MODS_NS }
    node.xpath('mods:namePart[not(@type)]',ns).each { |v| result += "#{v.text} "}
    (v = node.at_xpath('mods:namePart[@type="family"]',ns)) and result += v.text
    (v = node.at_xpath('mods:namePart[@type="given"]',ns)) and result += ", #{v.text}"
    (v = node.at_xpath('mods:namePart[@type="date"]',ns)) and result += ", #{v.text}"
    (v = node.at_xpath('mods:displayForm',ns)) and result += " (#{v.text})"
    node.xpath('mods:role[mods:roleTerm[@type="text"]!="creator"]',ns).each { |v| result += " (#{v.text})"}
    result.gsub(/\s+/," ").strip
  end
end
end