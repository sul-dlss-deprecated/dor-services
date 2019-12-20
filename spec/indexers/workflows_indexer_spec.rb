# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::WorkflowsIndexer do
  let(:obj) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }
  let(:indexer) { described_class.new(resource: obj) }

  describe '#to_solr' do
    let(:solr_doc) { indexer.to_solr }
    let(:xml) do
      <<~XML
        <workflows objectId="druid:ab123cd4567">
          <workflow repository="dor" objectId="druid:ab123cd4567" id="accessionWF">
            <process version="1" priority="0" note="" lifecycle="submitted" laneId="default" elapsed="" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="start-accession"/>
            <process version="1" priority="0" note="common-accessioning-stage-a.stanford.edu" lifecycle="described" laneId="default" elapsed="0.258" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="descriptive-metadata"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.188" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="rights-metadata"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.255" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="content-metadata"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.948" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="technical-metadata"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.15" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="remediate-object"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.479" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="shelve"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="published" laneId="default" elapsed="1.188" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="publish"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.251" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="provenance-metadata"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="2.257" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="sdr-ingest-transfer"/>
            <process version="1" priority="0" note="preservationIngestWF completed on preservation-robots1-stage.stanford.edu" lifecycle="deposited" laneId="default" elapsed="1.0" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="sdr-ingest-received"/>
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.246" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="reset-workspace"/>
            <process version="1" priority="0" note="common-accessioning-stage-a.stanford.edu" lifecycle="accessioned" laneId="default" elapsed="1.196" attempts="0" datetime="2019-01-28T20:41:12+00:00" status="completed" name="end-accession"/>
          </workflow>
          <workflow repository="dor" objectId="druid:ab123cd4567" id="assemblyWF">
            <process version="1" priority="0" note="" lifecycle="pipelined" laneId="default" elapsed="" attempts="0" datetime="2019-01-28T20:40:18+00:00" status="completed" name="start-assembly"/>
            <process version="1" priority="0" note="" lifecycle="" laneId="default" elapsed="" attempts="0" datetime="2019-01-28T20:40:18+00:00" status="skipped" name="jp2-create"/>
            <process version="1" priority="0" note="sul-robots1-test.stanford.edu" lifecycle="" laneId="default" elapsed="0.25" attempts="0" datetime="2019-01-28T20:40:18+00:00" status="completed" name="checksum-compute"/>
            <process version="1" priority="0" note="sul-robots1-test.stanford.edu" lifecycle="" laneId="default" elapsed="0.306" attempts="0" datetime="2019-01-28T20:40:18+00:00" status="completed" name="exif-collect"/>
            <process version="1" priority="0" note="sul-robots2-test.stanford.edu" lifecycle="" laneId="default" elapsed="0.736" attempts="0" datetime="2019-01-28T20:40:18+00:00" status="completed" name="accessioning-initiate"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="completed" name="start-assembly"/>
            <process version="2" priority="0" note="contentMetadata.xml exists" lifecycle="" laneId="default" elapsed="0.278" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="skipped" name="content-metadata-create"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="error" name="jp2-create"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="queued" name="checksum-compute"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="queued" name="exif-collect"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-29T22:51:09+00:00" status="queued" name="accessioning-initiate"/>
          </workflow>
          <workflow repository="dor" objectId="druid:ab123cd4567" id="disseminationWF">
            <process version="1" priority="0" note="common-accessioning-stage-b.stanford.edu" lifecycle="" laneId="default" elapsed="0.826" attempts="0" datetime="2019-01-28T20:46:57+00:00" status="completed" name="cleanup"/>
          </workflow>
          <workflow repository="dor" objectId="druid:ab123cd4567" id="hydrusAssemblyWF">
            <process version="1" priority="0" note="" lifecycle="registered" laneId="default" elapsed="" attempts="0" datetime="2019-01-28T20:37:43+00:00" status="completed" name="start-deposit"/>
            <process version="1" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:37:43+00:00" status="completed" name="submit"/>
            <process version="1" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:37:43+00:00" status="completed" name="approve"/>
            <process version="1" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:37:43+00:00" status="completed" name="start-assembly"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:48:17+00:00" status="completed" name="submit"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:48:17+00:00" status="completed" name="approve"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="0.0" attempts="0" datetime="2019-01-28T20:48:18+00:00" status="completed" name="start-assembly"/>
          </workflow>
          <workflow repository="dor" objectId="druid:ab123cd4567" id="versioningWF">
            <process version="2" priority="0" note="" lifecycle="opened" laneId="default" elapsed="" attempts="0" datetime="2019-01-28T20:48:16+00:00" status="completed" name="start-version"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="" attempts="1" datetime="2019-01-28T20:48:16+00:00" status="completed" name="submit-version"/>
            <process version="2" priority="0" note="" lifecycle="" laneId="default" elapsed="" attempts="1" datetime="2019-01-28T20:48:16+00:00" status="completed" name="start-accession"/>
          </workflow>
        </workflows>
      XML
    end

    let(:accession_json) do
      { 'processes' => [
        { 'name' => 'start-accession' },
        { 'name' => 'descriptive-metadata' },
        { 'name' => 'rights-metadata' },
        { 'name' => 'content-metadata' },
        { 'name' => 'technical-metadata' },
        { 'name' => 'remediate-object' },
        { 'name' => 'shelve' },
        { 'name' => 'publish' },
        { 'name' => 'provenance-metadata' },
        { 'name' => 'sdr-ingest-transfer' },
        { 'name' => 'sdr-ingest-received' },
        { 'name' => 'reset-workspace' },
        { 'name' => 'end-accession' }
      ] }
    end

    let(:assembly_json) do
      { 'processes' => [
        { 'name' => 'start-assembly' },
        { 'name' => 'content-metadata-create' },
        { 'name' => 'jp2-create' },
        { 'name' => 'checksum-compute' },
        { 'name' => 'exif-collect' },
        { 'name' => 'accessioning-initiate' }
      ] }
    end

    let(:dissemination_json) do
      {
        'processes' => [
          { 'name' => 'cleanup' }
        ]
      }
    end

    let(:hydrus_json) do
      { 'processes' => [
        { 'name' => 'start-deposit' },
        { 'name' => 'submit' },
        { 'name' => 'approve' },
        { 'name' => 'start-assembly' }
      ] }
    end

    let(:versioning_json) do
      { 'processes' => [
        { 'name' => 'start-version' },
        { 'name' => 'submit-version' },
        { 'name' => 'start-accession' }
      ] }
    end

    before do
      allow(Dor::Config.workflow.client).to receive(:workflow_template).with('accessionWF').and_return(accession_json)
      allow(Dor::Config.workflow.client).to receive(:workflow_template).with('assemblyWF').and_return(assembly_json)
      allow(Dor::Config.workflow.client).to receive(:workflow_template).with('disseminationWF').and_return(dissemination_json)
      allow(Dor::Config.workflow.client).to receive(:workflow_template).with('hydrusAssemblyWF').and_return(hydrus_json)
      allow(Dor::Config.workflow.client).to receive(:workflow_template).with('versioningWF').and_return(versioning_json)

      allow(Dor::Config.workflow.client.workflow_routes).to receive(:all_workflows)
        .and_return(Dor::Workflow::Response::Workflows.new(xml: xml))
    end

    describe 'workflow_status_ssim' do
      subject { solr_doc['workflow_status_ssim'] }

      it { is_expected.to eq ['accessionWF|completed|0|dor', 'assemblyWF|active|1|dor', 'disseminationWF|completed|0|dor', 'hydrusAssemblyWF|completed|0|dor', 'versioningWF|completed|0|dor'] }
    end
  end
end
