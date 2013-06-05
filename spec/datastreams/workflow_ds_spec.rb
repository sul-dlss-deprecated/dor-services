require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'

describe Dor::WorkflowDs do
  let(:dsxml) { <<-EOF
        <workflows objectId="druid:bm570gc7690">
          <workflow repository="dor" objectId="druid:bm570gc7690" id="accessionWF">
            <process priority="0" lifecycle="accessioned" elapsed="0.0" attempts="0" datetime="2012-06-22T13:29:26-0700" status="waiting" name="cleanup"/>
            <process priority="0" note="Needs more MODS!" lifecycle="submitted" elapsed="0.0" attempts="0" datetime="2012-06-22T13:29:26-0700" status="completed" name="start-accession"/>
            <process priority="0" lifecycle="described" elapsed="0.643" attempts="1" datetime="2012-06-22T13:29:39-0700" status="completed" name="descriptive-metadata"/>
            <process priority="0" elapsed="0.723" attempts="1" datetime="2012-06-22T13:29:39-0700" status="completed" name="content-metadata"/>
            <process priority="0" elapsed="0.849" attempts="1" datetime="2012-06-22T13:29:47-0700" status="completed" name="rights-metadata"/>
            <process priority="0" elapsed="5.587" attempts="1" datetime="2012-06-22T13:30:52-0700" status="completed" name="remediate-object"/>
            <process priority="0" elapsed="3.631" attempts="1" datetime="2012-06-22T13:31:39-0700" status="completed" name="shelve"/>
            <process priority="0" lifecycle="published" elapsed="9.473" attempts="1" datetime="2012-06-22T13:33:30-0700" status="completed" name="publish"/>
            <process priority="0" elapsed="2.969" attempts="3" datetime="2012-11-21T11:38:50-0800" status="completed" name="technical-metadata"/>
            <process priority="0" elapsed="0.507" attempts="1" datetime="2012-11-21T11:41:39-0800" status="completed" name="provenance-metadata"/>
            <process priority="0" elapsed="0.0" attempts="1" datetime="2013-01-10T15:17:54-0800" status="completed" name="sdr-ingest-transfer"/>
          </workflow>
          <workflow repository="dor" objectId="druid:bm570gc7690" id="assemblyWF">
            <process version="1" priority="20" note="dor" lifecycle="inprocess" elapsed="0.0" archived="true" attempts="0" datetime="2012-06-22T13:05:43-0700" status="completed" name="start-assembly"/>
            <process version="1" priority="20" note="dor" elapsed="0.394" archived="true" attempts="1" datetime="2012-06-22T13:27:25-0700" status="completed" name="jp2-create"/>
            <process version="1" priority="20" note="dor" elapsed="2.996" archived="true" attempts="1" datetime="2012-06-22T13:28:54-0700" status="completed" name="checksum-compute"/>
            <process version="1" priority="20" note="dor" elapsed="0.296" archived="true" attempts="1" datetime="2012-06-22T13:28:55-0700" status="completed" name="exif-collect"/>
            <process version="1" priority="20" note="dor" elapsed="2.447" archived="true" attempts="1" datetime="2012-06-22T13:29:26-0700" status="completed" name="accessioning-initiate"/>
          </workflow>
          <workflow repository="dor" objectId="druid:bm570gc7690" id="digitizationWF">
            <process priority="30" lifecycle="registered" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="completed" name="initiate"/>
            <process priority="30" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="waiting" name="digitize"/>
            <process priority="30" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="waiting" name="start-accession"/>
          </workflow>
          <workflow repository="dor" objectId="druid:bm570gc7690" id="disseminationWF">
            <process version="1" priority="0" note="dor" lifecycle="published" elapsed="9.355" archived="true" attempts="1" datetime="2012-06-22T13:33:30-0700" status="completed" name="publish"/>
          </workflow>
        </workflows>
    EOF
  }

  let(:ds) { Dor::WorkflowDs.from_xml(dsxml) }

  context "Marshalling to and from a Fedora Datastream" do
    it "creates itself from xml" do
      ds.workflows.size.should == 4
    end
  end

  describe "#current_priority" do
    it "searches through all the workflows and returns the first active priority it finds" do
      Dor::Workflow::Document.any_instance.stub(:definition).and_return(nil)
      ds.current_priority.should == 30
    end

    it "returns 0 if none of the workflows are expedited" do
      xml = <<-EOF
            <workflows objectId="druid:bm570gc7690">
              <workflow repository="dor" objectId="druid:bm570gc7690" id="digitizationWF">
                <process priority="0" lifecycle="registered" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="completed" name="initiate"/>
                <process priority="0" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="waiting" name="digitize"/>
                <process priority="0" elapsed="0.0" attempts="0" datetime="2012-03-29T15:22:18-0700" status="waiting" name="start-accession"/>
              </workflow>
              <workflow repository="dor" objectId="druid:bm570gc7690" id="disseminationWF">
                <process version="1" priority="0" note="dor" lifecycle="published" elapsed="9.355" archived="true" attempts="1" datetime="2012-06-22T13:33:30-0700" status="completed" name="publish"/>
              </workflow>
            </workflows>
      EOF
      ds2 = Dor::WorkflowDs.from_xml(xml)

      Dor::Workflow::Document.any_instance.stub(:definition).and_return(nil)
      ds2.current_priority.should == 0
    end
  end

end