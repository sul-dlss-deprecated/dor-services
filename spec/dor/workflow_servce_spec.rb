require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

#TODO move DOR_URI to all the different environments

describe Dor::WorkflowService do  
  before(:all) do
    with_warnings_suppressed do
      Dor::WF_URI = 'https://dortest.stanford.edu/workflow'
      Dor::CREATE_WORKFLOW = true
      XML = <<-EOXML
      <workflow id="etdSubmitWF">
           <process name="register-object" status="completed" attempts="1" />
           <process name="submit" status="waiting" />
           <process name="reader-approval" status="waiting" />
           <process name="registrar-approval" status="waiting" />
           <process name="start-accession" status="waiting" />
      </workflow>
      EOXML
      
    end
  end
  
  after(:all) do
    with_warnings_suppressed do
      Dor::CREATE_WORKFLOW = false
    end
  end
  
  before(:each) do
    @repo = 'dor'
    @druid = 'druid:123'
    @wf_full_uri = Dor::WF_URI + '/' + @repo + '/objects/' + @druid + '/workflows/etdSubmitWF'
    @wf_xml = XML
    
    @mock_logger = mock('logger').as_null_object
    Rails.stub!(:logger).and_return(@mock_logger)
  end
  
  describe "#create_workflow" do
    it "should pass workflow xml to the DOR workflow service and return the URL to the workflow" do
      pending
      res = Net::HTTPSuccess.new("", "", "")
      
      LyberCore::Connection.should_receive(:put).with(@wf_full_uri, @wf_xml).and_yield(res)
      Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', @wf_xml)
    end
    
    it "should log an error and return false if the PUT to the DOR workflow service throws an exception" do
      pending
      ex = Exception.new("exception thrown")
      LyberCore::Connection.should_receive(:put).and_raise(ex)

      lambda{ Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', @wf_xml) }.should raise_error(Exception, "exception thrown")
    end
    
    it "should pass workflow xml to the DOR workflow service and return the URL to the workflow" do
      pending
      res = Net::HTTPSuccess.new("", "", "")
      
      LyberCore::Connection.should_receive(:put).with(@wf_full_uri, @wf_xml).and_yield(res)
      Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', XML)
    end
    
    
  end
  
  describe "#update_workflow_status" do
    before(:each) do
      @process_uri = '' << @wf_full_uri << '/reader-approval'
      @process_xml = '<process name="reader-approval" status="completed" elapsed="0" />'
      
    end
    
    it "should update workflow status and return true if successful" do
      pending
      res = Net::HTTPSuccess.new("", "", "")
      
      LyberCore::Connection.should_receive(:put).with(@process_uri, @process_xml).and_yield(res)
      Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed")
    end
        
    it "should return false if the PUT to the DOR workflow service throws an exception" do
      pending
      ex = Exception.new("exception thrown")
      LyberCore::Connection.should_receive(:put).and_raise(ex)
      lambda{ Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed")}.should raise_error(Exception, "exception thrown")
    end
  end
  
  describe "#update_workflow_error_status" do
    before(:each) do
      @process_uri = '' << @wf_full_uri << '/reader-approval'
      @process_xml = '<process name="reader-approval" status="error" errorMessage="Some exception" errorText="The optional stacktrace" />'
      
    end
    
    it "should update workflow status to error and return true if successful" do
      pending
      res = Net::HTTPSuccess.new("", "", "")
      
      LyberCore::Connection.should_receive(:put).with(@process_uri, @process_xml).and_yield(res)
      Dor::WorkflowService.update_workflow_error_status(@repo, @druid, "etdSubmitWF", "reader-approval", "Some exception", "The optional stacktrace")
    end
        
    it "should return false if the PUT to the DOR workflow service throws an exception" do
      pending
      ex = Exception.new("exception thrown")
      LyberCore::Connection.should_receive(:put).and_raise(ex)
      lambda{ Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed")}.should raise_error(Exception, "exception thrown")
    end
  end
  
  describe "#get_workflow_status" do
    it "parses workflow xml and returns status as a string" do
      pending
      LyberCore::Connection.should_receive(:get).with('https://dortest.stanford.edu/workflow/dor/objects/druid:123/workflows/etdSubmitWF').
                    and_return('<process name="registrar-approval" status="completed" />')
      
      Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval').should == 'completed'
    end
    
    it "should throw an exception if it fails for any reason" do
      pending
      ex = Exception.new("exception thrown")
      LyberCore::Connection.should_receive(:get).and_raise(ex)
      
      lambda{ Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval')}.should raise_error(Exception, "exception thrown")
    end
    
    it "should throw an exception if it cannot parse the response" do
      pending
      LyberCore::Connection.should_receive(:get).and_return('something not xml')
      
      lambda{ Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval')}.should raise_error(Exception, "Unable to parse response:\nsomething not xml")
    end
  end
  
  describe "#get_workflow_xml" do
    it "returns the xml for a given repository, druid, and workflow" do
      pending
      xml = '<workflow id="etdSubmitWF"><process name="registrar-approval" status="completed" /></workflow>'
      LyberCore::Connection.should_receive(:get).with('https://dortest.stanford.edu/workflow/dor/objects/druid:123/workflows/etdSubmitWF').
                    and_return(xml)
    
      Dor::WorkflowService.get_workflow_xml('dor', 'druid:123', 'etdSubmitWF').should == xml
    end
  end
end