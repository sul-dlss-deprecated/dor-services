# frozen_string_literal: true

require 'spec_helper'

describe Dor::AdministrativeMetadataDS do
  context 'defaults terms' do
    it '#default_workflow_lane gets and sets the attribute defaults/initiateWorkflow/@lane' do
      ds = Dor::AdministrativeMetadataDS.new
      ds.default_workflow_lane = 'slow'

      expect(ds.to_xml).to be_equivalent_to(<<-XML
        <administrativeMetadata>
          <defaults>
            <initiateWorkflow lane="slow"/>
          </defaults>
        </administrativeMetadata>
      XML
                                           )
      expect(ds.default_workflow_lane).to eq('slow')
    end

    it '#default_shelving_path gets and sets the attribute defaults/shelving/@path ' do
      ds = Dor::AdministrativeMetadataDS.new
      ds.default_shelving_path = '/hoover'

      expect(ds.to_xml).to be_equivalent_to(<<-XML
        <administrativeMetadata>
          <defaults>
            <shelving path="/hoover"/>
          </defaults>
        </administrativeMetadata>
      XML
                                           )
      expect(ds.default_shelving_path).to eq('/hoover')
    end
  end
end
