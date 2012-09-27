module Dor
class EmbargoMetadataDS < ActiveFedora::NokogiriDatastream
  include SolrDocHelper
  
  before_create :ensure_non_versionable

  set_terminology do |t|
    t.root(:path => "embargoMetadata")
    t.status(:index_as => [:searchable, :facetable])
    t.release_date(:path => "releaseDate")#, :data_type => :date)
    t.release_access(:path => "releaseAccess")
  end
  
  # Default EmbargoMetadataDS xml 
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.embargoMetadata {
        xml.status
        xml.releaseDate
        xml.releaseAccess
      }
    end
    return builder.doc
  end

  def to_solr solr_doc = {}, *args
    super
    add_solr_value(solr_doc, 'embargo_release_date', self.release_date.utc.strftime('%FT%TZ') , :date, [:searchable]) rescue nil

    solr_doc
  end
  
  def ensure_non_versionable
    self.versionable = "false"
  end
  
  #################################################################################
  # Convenience methods to get and set embargo properties
  # Hides complexity/verbosity of OM TermOperators for simple, non-repeating values 
  #################################################################################  

  def status=(new_status)
    update_values([:status] => new_status)
    self.dirty = true
  end
  
  def status
    term_values(:status).first
  end
  
  # Sets the release date.  Converts the date to beginning-of-day, UTC to help with Solr indexing
  # @param [Time] rd A Time object represeting the release date.  By default, it is set to now
  def release_date=(rd=Time.now)
		update_values([:release_date] => rd.beginning_of_day.utc.xmlschema)
    	self.content=self.ng_xml.to_s
		self.dirty = true
  end
  
  # Current releaseDate value
  # @return [Time]
  def release_date
    Time.parse(term_values(:release_date).first)
  end
  
  # @return [Nokogiri::XML::Element] The releaseAccess node
  def release_access_node
    find_by_terms(:release_access).first
  end
  
  # Sets the embargaAccess node
  # @param [Nokogiri::XML::Document] new_doc Document that will replace the existing releaseAccess node
  def release_access_node=(new_doc)
    if(new_doc.root.name != 'releaseAccess')
      raise "Trying to replace releaseAccess with a non-releaseAccess document"
    end
    
    term_value_delete(:select => '//embargoMetadata/releaseAccess')
    ng_xml.root.add_child(new_doc.root.clone)
    self.dirty = true
  end
  
end
end
