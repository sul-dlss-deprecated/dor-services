# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::DecommissionService do
  describe '#decommission' do
    subject(:service) { described_class.new(obj) }

    let(:dummy_obj) do
      Dor::AdminPolicyObject.new(pid: 'old:apo')
    end

    let(:obj) do
      Dor::Item.new.tap do |o|
        o.add_relationship :is_member_of, dummy_obj
        o.add_relationship :is_governed_by, dummy_obj
      end
    end

    let(:graveyard_apo) do
      Dor::AdminPolicyObject.new(pid: 'new:apo')
    end

    before do
      allow(dummy_obj).to receive(:rels_ext).and_return(double('rels_ext', content_will_change!: true, content: ''))
      allow(graveyard_apo).to receive(:rels_ext).and_return(double('rels_ext', content_will_change!: true, content: ''))

      allow(Dor::SearchService).to receive(:sdr_graveyard_apo_druid)
      allow(ActiveFedora::Base).to receive(:find) { graveyard_apo }
      service.decommission ' test '
    end

    it 'removes existing isMemberOf and isGovernedBy relationships' do
      expect(obj.relationships(:is_member_of_collection)).to be_empty
      expect(obj.relationships(:is_member_of)).to be_empty
      expect(obj.relationships(:is_governed_by)).not_to include('info:fedora/old:apo')
    end

    it 'adds an isGovernedBy relationship to the SDR graveyard APO' do
      expect(obj.relationships(:is_governed_by)).to eq(['info:fedora/new:apo'])
    end

    it 'clears out rightsMetadata and contentMetadata' do
      expect(obj.rightsMetadata.content).to eq('<rightsMetadata/>')
      expect(obj.contentMetadata.content).to eq('<contentMetadata/>')
    end

    it "adds a 'Decommissioned: tag" do
      # make sure the tag is present in its normalized form
      expect(obj.identityMetadata.tags).to include('Decommissioned : test')
    end
  end
end
