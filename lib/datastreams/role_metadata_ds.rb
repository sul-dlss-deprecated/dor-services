class RoleMetadataDS < ActiveFedora::NokogiriDatastream
  include SolrDocHelper
  
  set_terminology do |t|
    t.root :path => 'roleMetadata', :xmlns => '', :namespace_prefix => nil

    t.actor :namespace_prefix => nil do
      t.identifier :namespace_prefix => nil do
        t.type_ :path => {:attribute => 'type'}, :namespace_prefix => nil
      end
      t.name :namespace_prefix => nil
    end
    t.person :ref => [:actor], :path => 'person', :namespace_prefix => nil
    t.group  :ref => [:actor], :path => 'group', :namespace_prefix => nil

    t.role :namespace_prefix => nil do
      t.type_ :path => {:attribute => 'type'}
      t.person :ref => [:person]
      t.group  :ref => [:group]
    end
    
    t.manager    :ref => [:role], :attributes => {:type => 'manager'}, :namespace_prefix => nil
    t.depositor  :ref => [:role], :attributes => {:type => 'depositor'}, :namespace_prefix => nil
    t.reviewer   :ref => [:role], :attributes => {:type => 'reviewer'}, :namespace_prefix => nil
    t.viewer     :ref => [:role], :attributes => {:type => 'viewer'}, :namespace_prefix => nil
  end

  def to_solr(solr_doc=Hash.new,*args)
    self.find_by_xpath('/roleMetadata/role/*').each do |actor|
      role_type = actor.parent['type']
      val = [actor.at_xpath('identifier/@type'),actor.at_xpath('identifier/text()')].join ':'
      add_solr_value(solr_doc, "apo_role_#{actor.name}_#{role_type}", val, :string, [:searchable, :facetable])
      add_solr_value(solr_doc, "apo_role_#{role_type}", val, :string, [:searchable, :facetable])
      if ['manager','depositor'].include? role_type
        add_solr_value(solr_doc, "apo_register_permissions", val, :string, [:searchable, :facetable])
      end
    end
    solr_doc
  end
  
end