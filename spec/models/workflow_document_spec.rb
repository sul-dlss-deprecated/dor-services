require 'spec_helper'

describe Dor::Workflow::Document do

  before(:each) do
    # stub the wf definition. The workflow document updates the processes in the definition with the values from the xml.
    @wf_definition = double(Dor::WorkflowObject)
    wf_definition_procs = []
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name' => 'hello', 'lifecycle' => 'lc', 'status' => 'stat', 'sequence' => '1'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name' => 'goodbye', 'status' => 'waiting', 'sequence' => '2'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name' => 'technical-metadata', 'status' => 'error', 'sequence' => '3'})
    wf_definition_procs << Dor::Workflow::Process.new('accessionWF', 'dor', {'name' => 'some-other-step', 'sequence' => '4'})

    allow(@wf_definition).to receive(:processes).and_return(wf_definition_procs)
  end

  describe 'processes' do
    it 'should generate an empty response from empty xml' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workflow objectId="druid:mf777zb0743" id="sdrIngestWF"/>
      eos

      # xml=Nokogiri::XML(xml)
      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      expect(d.processes.length).to eq(0)
    end

    it 'should generate a process list based on the reified workflow which has sequence, not the processes list from the workflow service' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      eos

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      expect(d.processes.length).to eq(4)
      proc = d.processes.first
      expect(proc.name).to eq('hello')
      expect(proc.status).to eq('stat')
      expect(proc.lifecycle).to eq('lc')
      expect(proc.sequence).to eq('1')

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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      expect(d.expedited?).to be_falsey
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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      expect(d.expedited?).to be_truthy
    end
  end

  describe 'active?' do

    it 'returns true if there are any non-archived rows' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process lifecycle="submitted" elapsed="0.0" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
      </workflow>
      eos

      d = Dor::Workflow::Document.new(xml)
      expect(d.active?).to be_truthy
    end

    it 'returns false if there are only archived rows' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
      </workflow>
      eos

      d = Dor::Workflow::Document.new(xml)
      expect(d.active?).to be_falsey
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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr
      expect(doc[Solrizer.solr_name('workflow_status', :symbol)].first).to eq('accessionWF|active|0|dor')
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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr
      expect(doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr
      expect(doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
    end

    it 'should index the iso8601 UTC dates for completed and errored workflow steps' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:57-0800" status="error" name="hello"/>
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="" name="goodbye"/>
      </workflow>
      eos

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr

      expect(doc).to match a_hash_including('wf_accessionWF_hello_dttsi' => '2012-11-07T00:18:57Z')
      expect(doc).to match a_hash_including('wf_accessionWF_technical-metadata_dttsi' => '2012-11-07T00:18:58Z')
    end

    it 'should only index dates for completed and errored workflow steps which include a date' do
      xml = <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="" status="error" name="hello"/>
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="" name="goodbye"/>
      </workflow>
      eos

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr

      expect(doc).to match a_hash_including('wf_accessionWF_technical-metadata_dttsi')
      expect(doc).not_to match a_hash_including('wf_accessionWF_hello_dttsi')
      expect(doc).not_to match a_hash_including('wf_accessionWF_start-accession_dttsi')
      expect(doc).not_to match a_hash_including('wf_accessionWF_goodbye_dttsi')
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

      d = Dor::Workflow::Document.new(xml)
      allow(d).to receive(:definition).and_return(@wf_definition)
      doc = d.to_solr
      expect(doc[Solrizer.solr_name('wf_error', :symbol)].first).to eq('accessionWF:technical-metadata:druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:')
    end
  end
end