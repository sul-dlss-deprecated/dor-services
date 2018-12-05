# frozen_string_literal: true

require 'spec_helper'

class PublishableItem < ActiveFedora::Base
  include Dor::Identifiable
  include Dor::Publishable
  include Dor::Rightsable
  include Dor::Itemizable
end

RSpec.describe Dor::Publishable do
  before do
    Dor.configure do
      stacks do
        host 'stacks.stanford.edu'
      end
    end
  end

  let(:item) do
    instantiate_fixture('druid:ab123cd4567', PublishableItem)
  end

  it 'has a rightsMetadata datastream' do
    expect(item.datastreams['rightsMetadata']).to be_a(ActiveFedora::OmDatastream)
  end

  describe '#build_rightsMetadata_datastream' do
    let(:apo) { instantiate_fixture('druid:fg890hi1234', Dor::AdminPolicyObject) }
    let(:rights_md) { apo.defaultObjectRights.content }

    before do
      allow(item).to receive(:admin_policy_object).and_return(apo)
    end

    it 'copies the default object rights' do
      expect(item.datastreams['rightsMetadata'].ng_xml.to_s).not_to be_equivalent_to(rights_md)
      item.build_rightsMetadata_datastream(item.rightsMetadata)
      expect(item.datastreams['rightsMetadata'].ng_xml.to_s).to be_equivalent_to(rights_md)
    end
  end
end
