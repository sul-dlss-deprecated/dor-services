module Dor
class RoleMetadataDS < ActiveFedora::OmDatastream
  include SolrDocHelper
  
  set_terminology do |t|
    t.root :path => 'roleMetadata'

    t.actor do
      t.identifier do
        t.type_ :path => {:attribute => 'type'}
      end
      t.name
    end
    t.person :ref => [:actor], :path => 'person'
    t.group  :ref => [:actor], :path => 'group'

    t.role do
      t.type_ :path => {:attribute => 'type'}
      t.person :ref => [:person]
      t.group  :ref => [:group]
    end
    
    t.manager    :ref => [:role], :attributes => {:type => 'manager'}
    t.depositor  :ref => [:role], :attributes => {:type => 'depositor'}
    t.reviewer   :ref => [:role], :attributes => {:type => 'reviewer'}
    t.viewer     :ref => [:role], :attributes => {:type => 'viewer'}
  end
  
  def self.xml_template
    Nokogiri::XML::Builder.new do |xml|
      xml.roleMetadata{
      }
    end.doc
  end
  

  def to_solr(solr_doc=Hash.new, *args)
    self.find_by_xpath('/roleMetadata/role/*').each do |actor|
      role_type = actor.parent['type']
      val = [actor.at_xpath('identifier/@type'),actor.at_xpath('identifier/text()')].join ':'
      add_solr_value(solr_doc, "apo_role_#{actor.name}_#{role_type}", val, :string, [:searchable, :facetable, :symbol])
      add_solr_value(solr_doc, "apo_role_#{role_type}", val, :string, [:searchable, :facetable, :symbol])
      if ['dor-apo-manager','dor-apo-depositor'].include? role_type
        add_solr_value(solr_doc, "apo_register_permissions", val, :string, [:symbol, :searchable, :facetable, :symbol])
      end
    end
    solr_doc
  end
  
end
end