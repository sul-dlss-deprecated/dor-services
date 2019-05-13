# frozen_string_literal: true

require 'spec_helper'

describe Dor::WorkflowDefinitionDs do
  let(:dsxml) do
    <<-EOF
        <workflow-def id="accessionWF" repository="dor">
          <process lifecycle="submitted" name="start-accession" status="completed" sequence="1">
            <label>Start Accessioning</label>
          </process>
          <process batch-limit="1000" error-limit="10" name="content-metadata" sequence="2">
            <label>Content Metadata</label>
            <prereq>start-accession</prereq>
          </process>
          <process batch-limit="1000" error-limit="10" lifecycle="described" name="descriptive-metadata" sequence="3">
            <label>Descriptive Metadata</label>
            <prereq>start-accession</prereq>
          </process>
        </workflow-def>
    EOF
  end

  let(:ds) { described_class.from_xml(dsxml) }

  context 'Marshalling to and from a Fedora Datastream' do
    it 'creates itself from xml' do
      expect(ds.name).to eq('accessionWF')
    end
  end
end
