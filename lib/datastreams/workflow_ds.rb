class WorkflowDs < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  set_terminology do |t|
    t.root(:path=>"workflows")
    t.workflow {
      t.workflowId(:path=>{:attribute => "id"})
      t.process {
        t._name(:path=>{:attribute=>"name"})
        t.status(:path=>{:attribute=>"status"})
        t.timestamp(:path=>{:attribute=>"datetime"})#, :data_type => :date)
        t.elapsed(:path=>{:attribute=>"elapsed"})
        t.lifecycle(:path=>{:attribute=>"lifecycle"})
        t.attempts(:path=>{:attribute=>"attempts"}, :index_as => [:not_searchable])
      }
    }
  end

  def initialize(*args)
    self.field_mapper = UtcDateFieldMapper.new
    super
  end
  
  def workflows
    self.workflow.nodeset.collect { |wf_node| Workflow::Document.new wf_node.to_xml }
  end
  
  def to_solr(solr_doc=Hash.new, *args)
    super
#    self.workflows.each { |wf| wf.to_solr(solr_doc, *args) }
  end
  
end