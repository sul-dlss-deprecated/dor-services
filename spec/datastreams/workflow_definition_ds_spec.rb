require 'spec_helper'
require 'nokogiri'
require 'equivalent-xml'

describe Dor::WorkflowDefinitionDs do
  let(:dsxml) { <<-EOF
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
  }

  let(:ds) { Dor::WorkflowDefinitionDs.from_xml(dsxml) }

  context "Marshalling to and from a Fedora Datastream" do
    it "creates itself from xml" do
      ds.name.should == 'accessionWF'
    end
  end

  describe "#initial_workflow" do
    it "creates workflow xml from the definition in its content" do
      expected =<<-EOXML
        <workflow id="accessionWF">
           <process name="start-accession" status="completed" lifecycle="submitted" attempts="1"/>
           <process name="content-metadata" status="waiting"/>
           <process name="descriptive-metadata" status="waiting" lifecycle="described"/>
        </workflow>
      EOXML
      ds.initial_workflow.should be_equivalent_to(expected)
    end
  end

end
