Dor::Identifiable.on_upgrade '3.6.1', 'Record Remediation Version' do |obj|
  version_tag = obj.identityMetadata.find_by_terms(:tag).find { |e| e.text =~ /Remediated By\s*:\s*(.+)/ }
  add_tag = false
  if version_tag
    current_version = Gem::Version.new($1)
    if current_version < Gem::Version.new(Dor::VERSION)
      version_tag.remove
      add_tag = true
    end
  else
    add_tag = true
  end
  
  if add_tag
    obj.identityMetadata.add_value :tag, "Remediated By : #{Dor::VERSION}"
  end
  add_tag
end