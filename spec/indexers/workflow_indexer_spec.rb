# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::WorkflowIndexer do
  let(:document) { Dor::Workflow::Document.new(xml) }
  let(:indexer) { described_class.new(document: document) }

  let(:wf_definition) { instance_double(Dor::WorkflowDefinitionDs, processes: wf_definition_procs) }
  let(:wf_definition_procs) do
    [
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step1, 'lifecycle' => 'lc', 'status' => 'stat', 'sequence' => '1'),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step2, 'status' => 'waiting', 'sequence' => '2', 'prerequisite' => ['hello']),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step3, 'status' => 'error', 'sequence' => '3'),
      Dor::Workflow::Process.new('accessionWF', 'dor', 'name' => step4, 'sequence' => '4')
    ]
  end

  let(:step1) { 'hello' }
  let(:step2) { 'goodbye' }
  let(:step3) { 'technical-metadata' }
  let(:step4) { 'some-other-step' }

  describe '#to_solr' do
    subject(:solr_doc) { indexer.to_solr.to_h }

    before do
      allow(document).to receive(:definition).and_return(wf_definition)
    end

    let(:xml) do
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
         datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
      </workflow>
      XML
    end

    it 'creates the workflow_status field with the workflow repository included' do
      expect(solr_doc[Solrizer.solr_name('workflow_status', :symbol)].first).to eq('accessionWF|active|0|dor')
    end

    context 'when the xml contains a process list with a waiting items that have a prerequisite' do
      let(:xml) do
        <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1" datetime="2012-11-06T16:18:24-0800" status="inprogress" name="hello"/>
        </workflow>
        XML
      end

      it 'indexes the right workflow status (active)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|active|1|dor'])
      end
    end

    context 'when all steps are completed or skipped' do
      let(:xml) do
        <<-XML
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
        XML
      end

      it 'indexes the right workflow status (completed)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
      end
    end

    context 'when a step has an empty status' do
      let(:xml) do
        <<-XML
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
        XML
      end

      it 'indexes the right workflow status (completed)' do
        expect(solr_doc).to match a_hash_including('workflow_status_ssim' => ['accessionWF|completed|0|dor'])
      end
    end

    context 'when the xml has dates for completed and errored steps' do
      let(:xml) do
        <<-XML
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
        XML
      end

      it 'indexes the iso8601 UTC dates' do
        expect(solr_doc).to match a_hash_including('wf_accessionWF_hello_dttsi' => '2012-11-07T00:18:57Z')
        expect(solr_doc).to match a_hash_including('wf_accessionWF_technical-metadata_dttsi' => '2012-11-07T00:18:58Z')
      end
    end

    context 'when the xml does not have dates for completed and errored steps' do
      let(:xml) do
        <<-XML
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
        XML
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
        <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:58-0800" status="error" errorMessage="druid:gv054hp4128 - Item error; caused by 413 Request Entity Too Large:" name="technical-metadata"/>
        </workflow>
        XML
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
        <<-XML
        <?xml version="1.0" encoding="UTF-8"?>
        <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
          <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
          <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:58-0800" status="error" errorMessage="#{error}" name="technical-metadata"/>
        </workflow>
        XML
      end

      let(:wf_error) { solr_doc[Solrizer.solr_name('wf_error', :symbol)] }

      it "truncates the error messages to below Solr's limit" do
        # 31 is the leader
        expect(wf_error.first.length).to be < 32_766
      end
    end
  end
end
