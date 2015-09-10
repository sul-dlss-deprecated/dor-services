require 'spec_helper'

describe Dor::AdministrativeMetadataDS do

  context "defaults terms" do
    it "#default_workflow_lane gets and sets the attribute defaults/initiateWorkflow/@lane" do
      ds = Dor::AdministrativeMetadataDS.new
      ds.default_workflow_lane = 'slow'

      ds.to_xml.should be_equivalent_to(<<-XML
        <administrativeMetadata>
          <defaults>
            <initiateWorkflow lane="slow"/>
          </defaults>
        </administrativeMetadata>
      XML
      )
      ds.default_workflow_lane.should == 'slow'
    end

    it "#default_shelving_path gets and sets the attribute defaults/shelving/@path " do
      ds = Dor::AdministrativeMetadataDS.new
      ds.default_shelving_path = '/hoover'

      ds.to_xml.should be_equivalent_to(<<-XML
        <administrativeMetadata>
          <defaults>
            <shelving path="/hoover"/>
          </defaults>
        </administrativeMetadata>
      XML
      )
      ds.default_shelving_path.should == '/hoover'
    end
  end
end
