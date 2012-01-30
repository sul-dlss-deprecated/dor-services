module DatastreamSpecSolrizer
  extend ActiveSupport::Concern
  include SolrDocHelper
  
  def datastream_spec_string
    s = controlGroup == 'E' ? content.to_s.length : size
    v = versionID.nil? ? '0' : versionID.to_s.split(/\./).last
    [dsid,controlGroup,mimeType,v,s,label].join("|")
  end
end

class ActiveFedora::Datastream
  include DatastreamSpecSolrizer
end
