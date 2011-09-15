class WorkflowDs < ActiveFedora::NokogiriDatastream 
  
  set_terminology do |t|
    t.root(:path=>"workflow", :xmlns => '', :namespace_prefix => nil)
    t.workflowId(:path=>{:attribute => "id"}, :index_as => [:displayable, :facetable])
    t.process(:path=>'process', :namespace_prefix => nil) {
      t._name(:path=>{:attribute=>"name"}, :index_as => [:displayable, :facetable, :sortable])
      t.status(:path=>{:attribute=>"status"}, :index_as => [:displayable, :facetable, :sortable])
      t.timestamp(:path=>{:attribute=>"datetime"}, :index_as => [:searchable, :sortable])
      t.elapsed(:path=>{:attribute=>"elapsed"})
      t.lifecycle(:path=>{:attribute=>"lifecycle"}, :index_as => [:displayable, :facetable, :sortable])
      t.attempts(:path=>{:attribute=>"attempts"})
    }
  end
    
end