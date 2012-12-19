require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'dor/datastreams/workflow_ds'
  describe Dor::WorkflowDs do
    before(:all) { stub_config }
    after(:all)  { unstub_config }

    before(:each) do
      @item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    end
    describe '[]' do
      it 'should build a Document object if there is xml' do
      xml='<?xml version="1.0" encoding="UTF-8"?>
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
      Dor::WorkflowService.stub(:get_workflow_xml).and_return(xml)
       accessionWF=@item.workflows['accessionWF']
       accessionWF.nil?.should == false
       
      end
      it 'should return nil if the xml is empty' do
      xml=''
      Dor::WorkflowService.stub(:get_workflow_xml).and_return(xml)
       @item.workflows['accessionWF'].nil?.should == true
    end
    end
    describe 'get_workflow' do
      it 'should build a Document object if there is xml' do
      xml='<?xml version="1.0" encoding="UTF-8"?>
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
      Dor::WorkflowService.stub(:get_workflow_xml).and_return(xml)
       accessionWF=@item.workflows.get_workflow 'accessionWF'
       accessionWF.nil?.should == false
       
      end
      it 'should return nil if the xml is empty' do
      xml=''
      Dor::WorkflowService.stub(:get_workflow_xml).and_return(xml)
       @item.workflows.get_workflow('accessionWF').nil?.should == true
    end
    it 'should request the workflow for a different repository if one is specified' do
      xml=''
      Dor::WorkflowService.should_receive(:get_workflow_xml).with('sdr','druid:ab123cd4567','accessionWF').and_return(xml)
       @item.workflows.get_workflow('accessionWF','sdr')
    end
    end
  end
   