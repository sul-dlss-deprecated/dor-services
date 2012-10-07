Dor::Identifiable.on_upgrade '3.14.8', 'Fix up invalid URIs in content-augmented datastreams' do |obj|
  bad_content_location_uri = begin
    URI.parse(obj.send("content-augmented").dsLocation)
    false
  rescue URI::InvalidURIError
    true
  rescue 
    false
  end

  next unless bad_content_location_uri

  parts = obj.send("content-augmented").dsLocation.split('/')
  parts[parts.length - 1] = URI.escape(parts.last)
  obj.send("content-augmented").dsLocation = parts.join('/')

  obj.send("content-augmented").save
end
