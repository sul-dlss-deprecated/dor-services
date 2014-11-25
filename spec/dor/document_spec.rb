require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::Workflow::Document do
  before(:each) do
    #stub the wf definition. The workflow document updates the processes in the definition with the values from the xml.
    @wf_definition=double(Dor::WorkflowObject)
    wf_definition_procs=[]
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name'=>'hello', 'lifecycle'=>'lc', 'status'=>'stat', 'sequence'=>'1'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name'=>'goodbye', 'status'=>'waiting', 'sequence'=>'2'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name'=>'technical-metadata', 'status'=>'error', 'sequence'=>'3'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name'=>'some-other-step', 'sequence'=>'4'})

    @wf_definition.stub(:processes).and_return(wf_definition_procs)
  end
  describe 'processes' do
    it 'should generate an empty response from empty xml' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workflow objectId="druid:mf777zb0743" id="sdrIngestWF"/>
      eos

      #xml=Nokogiri::XML(xml)
      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.processes.length.should == 0
    end

    it 'should generate a process list based on the reified workflow which has sequence, not the processes list from the workflow service' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.processes.length.should == 4
      proc=d.processes.first
      proc.name.should == 'hello'
      proc.status.should =='stat'
      proc.lifecycle.should == 'lc'
      proc.sequence.should == '1'

    end
  end
  describe 'expedited?' do
    it 'says false if there are no prioritized items' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.expedited?.should == false
    end
    it 'says true if there are incomplete prioritized items' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.expedited?.should == true
    end
  end 
  describe 'active?' do
    it 'should return true if there are any non-archived rows' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.expedited?.should == true
    end
    it 'should return false if there are only archived rows' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      d.expedited?.should == true
    end
  end
  describe 'to_solr' do
    it 'should create the workflow_status field with the workflow repository included' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)   
      d.stub(:definition).and_return(@wf_definition)  
      doc=d.to_solr
      doc['workflow_status_display'].first.should == 'accessionWF|active|0|dor'
    end

    it 'should index the right workflow status (completed) when all steps are completed or skipped' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="skipped" name="hello"/>
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="skipped" name="goodbye"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      doc=d.to_solr
      doc['workflow_status_display'].first.should == 'accessionWF|completed|0|dor'
    end
    
    it 'should index the right workflow status (completed) when all steps have status of completed/skipped/nil/empty' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="skipped" name="hello"/>
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="" name="goodbye"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)
      d.stub(:definition).and_return(@wf_definition)
      doc=d.to_solr
      doc['workflow_status_display'].first.should == 'accessionWF|completed|0|dor'
    end
    
    it 'should index error messages' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="error" errorMessage="druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:" name="technical-metadata"/>
      </workflow>
      eos

      d=Dor::Workflow::Document.new(xml)   
      d.stub(:definition).and_return(@wf_definition)  
      doc=d.to_solr
      doc['wf_error_display'].first.should == 'accessionWF:technical-metadata:druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:'
    end
  end
end