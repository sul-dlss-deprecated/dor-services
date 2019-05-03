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
end
