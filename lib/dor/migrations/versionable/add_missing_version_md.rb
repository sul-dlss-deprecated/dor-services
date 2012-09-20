Dor::Versionable.on_upgrade '3.12.2', 'Add missing versionMetadata' do |obj|
  vm = obj.datastreams['versionMetadata']
  return false if(!vm.new? || vm.content)# We already have a versionMetadata ds
  
  vm.content = vm.ng_xml.to_s
  true
end