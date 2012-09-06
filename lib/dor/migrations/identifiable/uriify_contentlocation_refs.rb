Dor::Identifiable.on_upgrade '3.11.6', 'Fix up invalid URIs in objects' do |obj|
  bad_content_location_uri = begin
    URI.parse(obj.content.contentLocation)
    false
  rescue
    true
  end

  next unless bad_content_location_uri

  parts = obj.content.contentLocation.split('/')
  parts[parts.length - 1] = URI.escape(parts.last)
  obj.content.contentLocation = parts.join('/')

  obj.content.save
end
