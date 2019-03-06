# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Workflow::Document do
  subject(:document) { described_class.new(xml) }

  let(:wf_definition) { instance_double(Dor::WorkflowDefinitionDs, processes: wf_definition_procs) }
  let(:wf_definition_procs) do
    [
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step1, 'lifecycle' => 'lc', 'status' => 'stat', 'sequence' => '1'),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step2, 'status' => 'waiting', 'sequence' => '2', 'prerequisite' => ['hello']),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step3, 'status' => 'error', 'sequence' => '3'),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step4, 'sequence' => '4')
    ]
  end
  let(:stub_wfo) { instance_double(Dor::WorkflowObject, definition: wf_definition) }

  before do
    # Wipe out the cache
    described_class.class_variable_set(:@@definitions, {})
    allow(Dor::WorkflowObject).to receive(:find_by_name).and_return(stub_wfo)
  end

  let(:step1) { 'hello' }
  let(:step2) { 'goodbye' }
  let(:step3) { 'technical-metadata' }
  let(:step4) { 'some-other-step' }

  describe '#processes' do
    subject(:processes) { document.processes }

    context 'when the xml is empty' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workflow objectId="druid:mf777zb0743" id="sdrIngestWF"/>
        eos
      end

      it 'generates an empty response' do
        expect(processes.length).to eq(0)
      end
    end

    context 'when the xml contains a process list with a incomplete items' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="inprogress" name="#{step1}"/>
        </workflow>
        eos
      end

      it 'assigns an owner to each' do
        expect(processes.map(&:owner)).to all(be_present)
      end
    end

    context 'when the xml contains a process list with an old version completed' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="1" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="#{step1}"/>
          <process version="1" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="#{step2}"/>
          <process version="1" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="#{step3}"/>
          <process version="1" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="#{step4}"/>
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="#{step1}"/>
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="queued" name="#{step2}"/>
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="queued" name="#{step3}"/>
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="queued" name="#{step4}"/>
        </workflow>
        eos
      end

      it 'returns only the most recent versions' do
        expect(processes.map(&:version)).to all(eq '2')
      end
    end

    context 'when the xml contains a process list with completed items' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        </workflow>
        eos
      end

      it 'generates a process list based on the reified workflow which has sequence, not the processes list from the workflow service' do
        expect(processes.length).to eq(4)
        proc = processes.first
        expect(proc.name).to eq('hello')
        expect(proc.status).to eq('stat')
        expect(proc.lifecycle).to eq('lc')
        expect(proc.sequence).to eq('1')
      end
    end
  end

  describe 'expedited?' do
    context 'when there are no prioritized items' do
      let(:xml) do
        <<~eos
          <?xml version="1.0" encoding="UTF-8"?>
          <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
            <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
             datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
            <process version="2" elapsed="0.0" archived="true" attempts="1"
             datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
          </workflow>
        eos
      end

      it { is_expected.not_to be_expedited }
    end

    context 'when there are incomplete prioritized items' do
      let(:xml) do
        <<~eos
          <?xml version="1.0" encoding="UTF-8"?>
          <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
            <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
             datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
            <process version="2" elapsed="0.0" archived="true" attempts="1"
             datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
          </workflow>
        eos
      end

      it { is_expected.to be_expedited }
    end
  end

  describe 'active?' do
    before do
      expect(Deprecation).to receive(:warn)
    end

    context 'when there are any non-archived rows' do
      let(:xml) do
        <<~eos
          <?xml version="1.0" encoding="UTF-8"?>
          <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
            <process lifecycle="submitted" elapsed="0.0" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
            <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
          </workflow>
        eos
      end

      it { is_expected.to be_active }
    end

    context 'when there are only archived rows' do
      let(:xml) do
        <<~eos
          <?xml version="1.0" encoding="UTF-8"?>
          <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:58-0800" status="waiting" priority="50" name="technical-metadata"/>
          </workflow>
        eos
      end

      it { is_expected.not_to be_active }
    end
  end

  describe '#to_solr' do
    subject(:solr_doc) { document.to_solr }

    let(:document) { described_class.new(xml) }

    before do
      allow(document).to receive(:definition).and_return(wf_definition)
    end

    let(:xml) do
      <<-eos
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      eos
    end

    it 'creates the workflow_status field with the workflow repository included' do
      expect(solr_doc[Solrizer.solr_name('workflow_status', :symbol)].first).to eq('accessionWF|active|0|dor')
    end

    context 'when the xml contains a process list with a waiting items that have a prerequisite' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="inprogress" name="hello"/>
        </workflow>
        eos
      end

      it 'indexes the right workflow status (active)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|active|1|dor'])
      end
    end

    context 'when all steps are completed or skipped' do
      let(:xml) do
        <<-eos
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
      end

      it 'indexes the right workflow status (completed)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
      end
    end

    context 'when a step has an empty status' do
      let(:xml) do
        <<-eos
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
      end

      it 'indexes the right workflow status (completed)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
      end
    end

    context 'when the xml has dates for completed and errored steps' do
      let(:xml) do
        <<-eos
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
      end

      it 'indexes the iso8601 UTC dates' do
        expect(solr_doc).to match a_hash_including('wf_accessionWF_hello_dttsi' => '2012-11-07T00:18:57Z')
        expect(solr_doc).to match a_hash_including('wf_accessionWF_technical-metadata_dttsi' => '2012-11-07T00:18:58Z')
      end
    end

    context 'when the xml does not have dates for completed and errored steps' do
      let(:xml) do
        <<-eos
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
      end

      it 'only indexes the dates on steps that include a date' do
        expect(solr_doc).to match a_hash_including('wf_accessionWF_technical-metadata_dttsi')
        expect(solr_doc).not_to match a_hash_including('wf_accessionWF_hello_dttsi')
        expect(solr_doc).not_to match a_hash_including('wf_accessionWF_start-accession_dttsi')
        expect(solr_doc).not_to match a_hash_including('wf_accessionWF_goodbye_dttsi')
      end
    end

    context 'when there are error messages' do
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:58-0800" status="error" errorMessage="druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:" name="technical-metadata"/>
        </workflow>
        eos
      end

      let(:wf_error) { solr_doc[Solrizer.solr_name('wf_error', :symbol)] }

      it 'indexes the error messages' do
        expect(wf_error).to eq ['accessionWF:technical-metadata:druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:']
      end
    end

    context 'when the error messages are crazy long' do
      let(:error_length) { 40_000 }
      let(:error) { (0...error_length).map { rand(65..90).chr }.join }
      let(:xml) do
        <<-eos
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:58-0800" status="error" errorMessage="#{error}" name="technical-metadata"/>
        </workflow>
        eos
      end

      let(:wf_error) { solr_doc[Solrizer.solr_name('wf_error', :symbol)] }

      it "truncates the error messages to below Solr's limit" do
        # 31 is the leader
        expect(wf_error.first.length).to be < 32_766
      end
    end
  end
end
