Dor::Processable.on_upgrade '3.5.0' do |obj|
  run = false
  # Touch workflows datastream to ensure it gets saved
  if obj.workflows.new?
    obj.workflows.content
    run = true
  end
      
  # Remove individual *WF datastreams
  obj.datastreams.each_pair do |dsid,ds| 
    if ds.controlGroup == 'E' and dsid =~ /WF$/
      ds.delete 
      run = true
    end
  end
  run
end
