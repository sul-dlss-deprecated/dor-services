module Dor
class WorkflowDs < ActiveFedora::NokogiriDatastream 
  include SolrDocHelper
  
  set_terminology do |t|
    t.root(:path=>"workflows")
    t.workflow {
      t.workflowId(:path=>{:attribute => "id"})
      t.process {
        t.name_(:path=>{:attribute=>"name"}, :index_as => [:displayable, :not_searchable])
        t.status(:path=>{:attribute=>"status"}, :index_as => [:displayable, :not_searchable])
        t.timestamp(:path=>{:attribute=>"datetime"}, :index_as => [:displayable, :not_searchable])#, :data_type => :date)
        t.elapsed(:path=>{:attribute=>"elapsed"}, :index_as => [:displayable, :not_searchable])
        t.lifecycle(:path=>{:attribute=>"lifecycle"}, :index_as => [:displayable, :not_searchable])
        t.attempts(:path=>{:attribute=>"attempts"}, :index_as => [:displayable, :not_searchable])
      }
    }
  end

  def initialize *args
    self.field_mapper = UtcDateFieldMapper.new
    super
  end

  def [](wf)
    node = self.ng_xml.at_xpath "/workflows/workflow[@id = '#{wf}']"
    node.nil? ? nil : Workflow::Document.new(node.to_xml)
  end

  def ensure_xml_loaded
    ng_xml
    self.xml_loaded = true
  end
  
  def ng_xml
    @ng_xml ||= Nokogiri::XML::Document.parse(content)
  end

  def content
    begin
      @content ||= Dor::WorkflowService.get_workflow_xml 'dor', self.pid, nil
    rescue RestClient::ResourceNotFound
      xml = Nokogiri::XML(%{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workflows objectId="#{self.pid}"/>})
      self.digital_object.datastreams.keys.each do |dsid|
        if dsid =~ /WF$/
          ds_content = Nokogiri::XML(Dor::WorkflowService.get_workflow_xml 'dor', self.pid, dsid)
          xml.root.add_child(ds_content.root)
        end
      end
      @content ||= xml.to_xml
    end
  end
  
  def workflows
    self.workflow.nodeset.collect { |wf_node| Workflow::Document.new wf_node.to_xml }
  end
  
  def graph(dir=nil)
    result = GraphViz.digraph(self.pid)
    sg = result.add_graph('rank') { |g| g[:rank => 'same'] }
    workflows.each do |wf|
      wf_name = wf.workflowId.first
      unless wf.nil?
        g = wf.graph(result)
        sg.add_node(g.root.id) unless g.nil?
      end
    end
    result['rankdir'] = dir || 'TB'
    result
  end
  
  def to_solr(solr_doc=Hash.new, *args)
#    super solr_doc, *args
    self.workflows.each { |wf| wf.to_solr(solr_doc, *args) }
    solr_doc
  end
  
end
end