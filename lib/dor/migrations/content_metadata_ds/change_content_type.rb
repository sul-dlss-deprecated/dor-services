Dor::ContentMetadataDS.on_upgrade '3.6.0', 'Change contentMetadata type attribute' do |ds|
  translations = { 'googleScannedBook' => 'book', 'etd' => 'file', 'eem' => 'file' }
  translations.any? do |old_type, new_type|
    current_type = ds.contentType.to_ary.first rescue ds.contentType
    (current_type == old_type) && (ds.contentType = new_type)
  end
end
