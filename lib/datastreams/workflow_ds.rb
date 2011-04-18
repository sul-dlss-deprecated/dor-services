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
  
  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.workflow {
          xml.process
      }   
    end

    return builder.doc
  end
  
  def to_solr(solr_doc = Solr::Document.new)
    workflow_name = self.term_values(:workflowId).first
    solr_doc << Solr::Field.new(:workflow_display => workflow_name)
    solr_doc << Solr::Field.new(:workflow_facet => workflow_name)
    
    self.find_by_terms(:process).each { |process|
      process_name = process['name']
      process_status = process['status']
      process_timestamp = DateTime.parse(process['datetime']).utc.to_time.xmlschema
      combined_process_name = "#{workflow_name}_#{process_name}"
      solr_doc << Solr::Field.new(:workflow_step_facet => process_name)
#      solr_doc << Solr::Field.new(:qualified_workflow_step_facet => combined_process_name)
      solr_doc << Solr::Field.new(:workflow_step_status_facet => process_status)
      
      solr_doc << Solr::Field.new(:"#{workflow_name}_process_facet" => process_name)
      
      solr_doc << Solr::Field.new(:"#{process_name}_status_facet" => process_status)
      solr_doc << Solr::Field.new(:"#{combined_process_name}_status_facet" => process_status)
      solr_doc << Solr::Field.new(:"#{combined_process_name}_status_dt" => process_timestamp)
      
      solr_doc << Solr::Field.new(:"workstep_status_#{process_status}_facet" => process_name)
      
      # THIS IS A TEMPORARY KLUDGE TO GET STUFF TO SHOW UP IN HYDRANGEA
      solr_doc << Solr::Field.new(:discover_access_group_t => 'public')
      solr_doc << Solr::Field.new(:read_access_group_t => 'public')
    }
    return solr_doc
  end
end