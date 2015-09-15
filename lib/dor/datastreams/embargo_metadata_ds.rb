module Dor
class EmbargoMetadataDS < ActiveFedora::OmDatastream

  before_create :ensure_non_versionable

  set_terminology do |t|
    t.root(:path => "embargoMetadata")
    t.status
    t.embargo_status(:path => 'status', :index_as => [:symbol])
    t.release_date(:path => "releaseDate", :index_as => [:dateable])
    t.release_access(:path => "releaseAccess")
    t.twenty_pct_status( :path => "twentyPctVisibilityStatus", :index_as => [:symbol])
    t.twenty_pct_release_date(:path => "twentyPctVisibilityReleaseDate")
  end

  # Default EmbargoMetadataDS xml
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.embargoMetadata {
        xml.status
        xml.releaseDate
        xml.releaseAccess
        xml.twentyPctVisibilityStatus
        xml.twentyPctVisibilityReleaseDate
      }
    end
    builder.doc
  end

  def to_solr solr_doc = {}, *args
    super
    #::Solrizer.insert_field(solr_doc, field_name, value, *index_types)
    rd1  = release_date
    rd20 = twenty_pct_release_date
    ::Solrizer.insert_field(solr_doc, 'embargo_release', rd1.utc.strftime('%FT%TZ'), :dateable) unless rd1.nil?
    ::Solrizer.insert_field(solr_doc, 'twenty_pct_visibility_release', rd20.utc.strftime('%FT%TZ'), :dateable) unless rd20.nil?
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
  end

  def status
    term_values(:status).first
  end

  # Sets the release date.  Converts the date to beginning-of-day, UTC to help with Solr indexing
  # @param [Time] rd A Time object represeting the release date.  By default, it is set to now
  def release_date=(rd=Time.now)
    update_values([:release_date] => rd.beginning_of_day.utc.xmlschema)
    self.content=ng_xml.to_s
  end

  # Current releaseDate value
  # @return [Time]
  def release_date
    rd = term_values(:release_date).first
    (rd.nil? || rd.empty?) ? nil : Time.parse(rd)
  end

  def twenty_pct_status=(new_status)
    update_values([:twenty_pct_status] => new_status)
    content_will_change!
  end

  def twenty_pct_status
    term_values(:twenty_pct_status).first
  end

  # Sets the 20% visibility release date.  Converts the date to beginning-of-day, UTC to help with Solr indexing
  # @param [Time] rd A Time object represeting the release date.  By default, it is set to now
  def twenty_pct_release_date=(rd=Time.now)
    update_values([:twenty_pct_release_date] => rd.beginning_of_day.utc.xmlschema)
    content_will_change!
  end

  # Current twentyPctVisibilityReleaseDate value
  # @return [Time]
  def twenty_pct_release_date
    rd = term_values(:twenty_pct_release_date).first
    (rd.nil? || rd.empty?) ? nil : Time.parse(rd)
  end

  # @return [Nokogiri::XML::Element] The releaseAccess node
  def release_access_node
    find_by_terms(:release_access).first
  end

  # Sets the embargaAccess node
  # @param [Nokogiri::XML::Document] new_doc Document that will replace the existing releaseAccess node
  def release_access_node=(new_doc)
    if (new_doc.root.name != 'releaseAccess')
      raise "Trying to replace releaseAccess with a non-releaseAccess document"
    end

    term_value_delete(:select => '//embargoMetadata/releaseAccess')
    ng_xml.root.add_child(new_doc.root.clone)
  end

end
end
