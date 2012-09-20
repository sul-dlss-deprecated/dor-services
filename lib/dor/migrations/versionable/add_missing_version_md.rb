Dor::Versionable.on_upgrade '3.12.2', 'Add missing versionMetadata' do |obj|
  run = false
  vm = obj.datastreams['versionMetadata']
  if(vm.content.nil? || vm.content.strip == '' || vm.new?) # We do not have a versionMetadata ds
    vm.content = vm.ng_xml.to_s
    run = true
  end
  run
end