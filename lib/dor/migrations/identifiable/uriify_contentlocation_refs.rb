Dor::Identifiable.on_upgrade '3.6.2.1', 'Fix up invalid URIs in objects' do |obj|
  bad_content_location_uri = begin
    URI.parse(obj.content.dsLocation)
    false
  rescue URI::InvalidURIError
    true
  rescue 
    false
  end

  next unless bad_content_location_uri

  parts = obj.content.dsLocation.split('/')
  parts[parts.length - 1] = URI.escape(parts.last)
  obj.content.dsLocation = parts.join('/')

  obj.content.save
end
