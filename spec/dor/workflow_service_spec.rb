require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

#TODO move DOR_URI to all the different environments

describe Dor::WorkflowService do  
  before(:all) do
    Dor::Config.push! { workflow.url = 'https://dortest.stanford.edu/workflow' }

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
    Dor::Config.pop!
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
  
  describe "#get_lifecycle" do
    it "returns a Time object reprenting when the milestone was reached" do
      xml = <<-EOXML
        <lifecycle objectId="druid:ct011cv6501">
            <milestone date="2010-04-27T11:34:17-0700">registered</milestone>
            <milestone date="2010-04-29T10:12:51-0700">inprocess</milestone>
            <milestone date="2010-06-15T16:08:58-0700">released</milestone>
        </lifecycle>
      EOXML
      @mock_resource.should_receive(:get).and_return(xml)
      Dor::WorkflowService.get_lifecycle('dor', 'druid:123', 'released').beginning_of_day.should == Time.parse('2010-06-15T16:08:58-0700').beginning_of_day
    end
    
    it "returns nil if the milestone hasn't been reached yet" do
      @mock_resource.should_receive(:get).and_return('<lifecycle/>')
      Dor::WorkflowService.get_lifecycle('dor', 'druid:abc', 'inprocess').should be_nil
    end

  end
  
  describe "#get_objects_for_workstep" do
    before :all do
      @repository = "dor"
      @workflow = "googleScannedBookWF"
      @completed = "google-download"
      @waiting = "process-content"
    end
    
    context "a query with one step completed and one waiting" do
      it "creates the URI string with only the one completed step" do
        @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{@repository}:#{@workflow}:#{@waiting}&completed=#{@repository}:#{@workflow}:#{@completed}")
        @mock_resource.should_receive(:get).and_return(%{<objects count="1"><object id="druid:ab123de4567"/><object id="druid:ab123de9012"/></objects>})
        Dor::WorkflowService.get_objects_for_workstep(@completed, @waiting, @repository, @workflow).should == ['druid:ab123de4567','druid:ab123de9012']
      end
    end
    
    context "a query with TWO steps completed and one waiting" do
      it "creates the URI string with the two completed steps correctly" do
        second_completed="google-convert"
        @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{@repository}:#{@workflow}:#{@waiting}&completed=#{@repository}:#{@workflow}:#{@completed}&completed=#{@repository}:#{@workflow}:#{second_completed}")
        @mock_resource.should_receive(:get).and_return(%{<objects count="1"><object id="druid:ab123de4567"/><object id="druid:ab123de9012"/></objects>})
        Dor::WorkflowService.get_objects_for_workstep([@completed,second_completed], @waiting, @repository, @workflow).should == ['druid:ab123de4567','druid:ab123de9012']
      end
    end
  
    context "a query using qualified workflow names for completed and waiting" do
      it "creates the URI string with the two completed steps across repositories correctly" do
        qualified_waiting = "#{@repository}:#{@workflow}:#{@waiting}"
        qualified_completed = "#{@repository}:#{@workflow}:#{@completed}"
        repo2 = "sdr"
        workflow2 = "sdrIngestWF"
        completed2="complete-deposit"
        completed3="ingest-transfer"
        qualified_completed2 = "#{repo2}:#{workflow2}:#{completed2}"
        qualified_completed3 = "#{repo2}:#{workflow2}:#{completed3}"
        @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{qualified_waiting}&completed=#{qualified_completed}&completed=#{qualified_completed2}")
        @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{qualified_waiting}&completed=#{qualified_completed3}")
        @mock_resource.should_receive(:get).and_return(%{<objects count="1"><object id="druid:ab123de4567"/><object id="druid:ab123de9012"/></objects>},%{<objects count="1"><object id="druid:ab123de4567"/><object id="druid:ab123de3456"/></objects>})
        Dor::WorkflowService.get_objects_for_workstep([qualified_completed, qualified_completed2, qualified_completed3], qualified_waiting).should == ['druid:ab123de4567']
      end
      
      it "creates the URI string with only one completed step passed in as a String" do
        qualified_waiting = "#{@repository}:#{@workflow}:#{@waiting}"
        qualified_completed = "#{@repository}:#{@workflow}:#{@completed}"
        repo2 = "sdr"
      
        @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{qualified_waiting}&completed=#{qualified_completed}")
        @mock_resource.should_receive(:get).and_return(%{<objects count="1"><object id="druid:ab123de4567"/></objects>})
        Dor::WorkflowService.get_objects_for_workstep(qualified_completed, qualified_waiting).should == ['druid:ab123de4567']
      end
    end
  end
  
  context "get empty workflow queue" do
    it "returns an empty list if it encounters an empty workflow queue" do
      repository = "dor"
      workflow = "googleScannedBookWF"
      completed = "google-download"
      waiting = "process-content"
      @mock_resource.should_receive(:[]).with("workflow_queue?waiting=#{repository}:#{workflow}:#{waiting}&completed=#{repository}:#{workflow}:#{completed}")
      @mock_resource.should_receive(:get).and_return(%{<objects count="0"/>})
      Dor::WorkflowService.get_objects_for_workstep(completed, waiting, repository, workflow).should == []
    end
  end
  
end