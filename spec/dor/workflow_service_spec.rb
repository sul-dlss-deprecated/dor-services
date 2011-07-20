require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

#TODO move DOR_URI to all the different environments

describe Dor::WorkflowService do  
  before(:all) do
    @saved_configuration = Dor::Config.to_hash
    Dor::Config.configure do
      workflow.url 'https://dortest.stanford.edu/workflow'
    end

    @wf_xml = <<-EOXML
    <workflow id="etdSubmitWF">
         <process name="register-object" status="completed" attempts="1" />
         <process name="submit" status="waiting" />
         <process name="reader-approval" status="waiting" />
         <process name="registrar-approval" status="waiting" />
         <process name="start-accession" status="waiting" />
    </workflow>
    EOXML
  end
  
  after(:all) do
    Dor::Config.configure(@saved_configuration)
  end
  
  before(:each) do
    @repo = 'dor'
    @druid = 'druid:123'
    
    @mock_logger = mock('logger').as_null_object
    Rails.stub!(:logger).and_return(@mock_logger)

    @mock_resource = mock('RestClient::Resource')
    @mock_resource.stub!(:[]).and_return(@mock_resource)
    RestClient::Resource.stub!(:new).and_return(@mock_resource)
  end
  
  describe "#create_workflow" do
    it "should pass workflow xml to the DOR workflow service and return the URL to the workflow" do
      @mock_resource.should_receive(:put).with(@wf_xml, anything()).and_return('')
      Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', @wf_xml)
    end
    
    it "should log an error and return false if the PUT to the DOR workflow service throws an exception" do
      ex = Exception.new("exception thrown")
      @mock_resource.should_receive(:put).and_raise(ex)
      lambda{ Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', @wf_xml) }.should raise_error(Exception, "exception thrown")
    end
    
    it "sets the create-ds param to the value of the passed in options hash" do
      @mock_resource.should_receive(:put).with(@wf_xml, :content_type => 'application/xml', 
                                                :params => {'create-ds' => false}).and_return('')
      Dor::WorkflowService.create_workflow(@repo, @druid, 'etdSubmitWF', @wf_xml, :create_ds => false)
    end
    
  end
  
  describe "#update_workflow_status" do
    before(:each) do
      @xml_re = /name="reader-approval"/
    end
    
    it "should update workflow status and return true if successful" do
      @mock_resource.should_receive(:put).with(@xml_re, { :content_type => 'application/xml' }).and_return('')
      Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed").should be_true
    end
        
    it "should return false if the PUT to the DOR workflow service throws an exception" do
      ex = Exception.new("exception thrown")
      @mock_resource.should_receive(:put).with(@xml_re, { :content_type => 'application/xml' }).and_raise(ex)
      lambda{ Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed") }.should raise_error(Exception, "exception thrown")
    end
  end
  
  describe "#update_workflow_error_status" do
    it "should update workflow status to error and return true if successful" do
      @mock_resource.should_receive(:put).with(/status="error"/, { :content_type => 'application/xml' }).and_return('')
      Dor::WorkflowService.update_workflow_error_status(@repo, @druid, "etdSubmitWF", "reader-approval", "Some exception", "The optional stacktrace")
    end
        
    it "should return false if the PUT to the DOR workflow service throws an exception" do
      ex = Exception.new("exception thrown")
      @mock_resource.should_receive(:put).with(/status="completed"/, { :content_type => 'application/xml' }).and_raise(ex)
      lambda{ Dor::WorkflowService.update_workflow_status(@repo, @druid, "etdSubmitWF", "reader-approval", "completed") }.should raise_error(Exception, "exception thrown")
    end
  end
  
  describe "#get_workflow_status" do
    it "parses workflow xml and returns status as a string" do
      @mock_resource.should_receive(:get).and_return('<process name="registrar-approval" status="completed" />')
      Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval').should == 'completed'
    end
    
    it "should throw an exception if it fails for any reason" do
      ex = Exception.new("exception thrown")
      @mock_resource.should_receive(:get).and_raise(ex)
      
      lambda{ Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval') }.should raise_error(Exception, "exception thrown")
    end
    
    it "should throw an exception if it cannot parse the response" do
      @mock_resource.should_receive(:get).and_return('something not xml')
      lambda{ Dor::WorkflowService.get_workflow_status('dor', 'druid:123', 'etdSubmitWF', 'registrar-approval') }.should raise_error(Exception, "Unable to parse response:\nsomething not xml")
    end
  end
  
  describe "#get_workflow_xml" do
    it "returns the xml for a given repository, druid, and workflow" do
      xml = '<workflow id="etdSubmitWF"><process name="registrar-approval" status="completed" /></workflow>'
      @mock_resource.should_receive(:get).and_return(xml)
      Dor::WorkflowService.get_workflow_xml('dor', 'druid:123', 'etdSubmitWF').should == xml
    end
  end
end