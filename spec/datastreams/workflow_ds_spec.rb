require 'spec_helper'

describe Dor::WorkflowDs do

  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:each) do
    @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
  end
  describe '[]' do
    it 'should build a Document object if there is xml' do
      xml = '<?xml version="1.0" encoding="UTF-8"?>
      <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
        <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:02-0800" status="completed" name="provenance-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:05-0800" status="completed" name="remediate-object"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:06-0800" status="completed" name="shelve"/>
        <process version="2" lifecycle="published" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:07-0800" status="completed" name="publish"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:09-0800" status="completed" name="sdr-ingest-transfer"/>
        <process version="2" lifecycle="accessioned" elapsed="0.0" archived="true" attempts="1"
            datetime="2012-11-06T16:19:10-0800" status="completed" name="cleanup"/>
        <process version="2" elapsed="0.0" archived="true" attempts="1"
          datetime="2012-11-06T16:19:13-0800" status="completed" name="rights-metadata"/>
        <process version="2" lifecycle="described" elapsed="0.0" archived="true" attempts="1"
          datetime="2012-11-06T16:19:15-0800" status="completed" name="descriptive-metadata"/>
        <process version="2" elapsed="0.0" archived="true" attempts="2"
          datetime="2012-11-06T16:19:16-0800" status="completed" name="content-metadata"/>'
      allow(Dor::Config.workflow.client).to receive(:get_workflow_xml).and_return(xml)
      accessionWF = @item.workflows['accessionWF']
      expect(accessionWF).not_to be_nil
    end
    it 'should return nil if the xml is empty' do
      allow(Dor::Config.workflow.client).to receive(:get_workflow_xml).and_return('')
      expect(@item.workflows['accessionWF']).to be_nil
    end
  end
  describe 'get_workflow' do
    it 'should build a Document object if there is xml' do
      xml = '<?xml version="1.0" encoding="UTF-8"?>
       <workflow repository="dor" objectId="druid:gv054hp4128" id="accessionWF">
         <process version="2" lifecycle="submitted" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:24-0800" status="completed" name="start-accession"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:18:58-0800" status="completed" name="technical-metadata"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:02-0800" status="completed" name="provenance-metadata"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:05-0800" status="completed" name="remediate-object"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:06-0800" status="completed" name="shelve"/>
         <process version="2" lifecycle="published" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:07-0800" status="completed" name="publish"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:09-0800" status="completed" name="sdr-ingest-transfer"/>
         <process version="2" lifecycle="accessioned" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:10-0800" status="completed" name="cleanup"/>
         <process version="2" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:13-0800" status="completed" name="rights-metadata"/>
         <process version="2" lifecycle="described" elapsed="0.0" archived="true" attempts="1"
           datetime="2012-11-06T16:19:15-0800" status="completed" name="descriptive-metadata"/>
         <process version="2" elapsed="0.0" archived="true" attempts="2"
           datetime="2012-11-06T16:19:16-0800" status="completed" name="content-metadata"/>'
      allow(Dor::Config.workflow.client).to receive(:get_workflow_xml).and_return(xml)
      accessionWF = @item.workflows.get_workflow 'accessionWF'
      expect(accessionWF).not_to be_nil
    end
    it 'should return nil if the xml is empty' do
      allow(Dor::Config.workflow.client).to receive(:get_workflow_xml).and_return('')
      expect(@item.workflows.get_workflow('accessionWF')).to be_nil
    end
    it 'should request the workflow for a different repository if one is specified' do
      expect(Dor::Config.workflow.client).to receive(:get_workflow_xml).with('sdr', 'druid:ab123cd4567', 'accessionWF').and_return('')
      @item.workflows.get_workflow('accessionWF', 'sdr')
    end
  end
end
