require 'spec_helper'

RSpec.describe Dor::EditableIndexer do
  let(:model) do
    Dor::AdminPolicyObject
  end
  before { stub_config }
  after { unstub_config }
  # @apo = instantiate_fixture('druid_zt570tx3016', Dor::AdminPolicyObject)

  let(:obj) { instantiate_fixture('druid_zt570tx3016', model) }
  let(:indexer) do
    described_class.new(resource: obj)
  end

  describe '#default_rights_for_indexing' do
    before do
      allow(obj).to receive(:default_rights).and_return('world')
    end

    it 'uses the OM template if the ds is empty' do
      expect(indexer.default_rights_for_indexing).to eq('World')
    end
  end

  describe '#to_solr' do
    let(:indexer) do
      Dor::AdminPolicyObject.resource_indexer.new(resource: obj)
    end
    let(:doc) { indexer.to_solr }

    before do
      allow(obj).to receive(:milestones).and_return({})
      allow(obj).to receive(:agreement).and_return('druid:agreement')
      allow(obj).to receive(:agreement_object).and_return(true)
    end

    it 'makes a solr doc' do
      expect(doc).to match a_hash_including('default_rights_ssim' => ['World']) # note that this is capitalized, because it comes from default_rights_for_indexing
      expect(doc).to match a_hash_including('agreement_ssim'      => ['druid:agreement'])
      # expect(doc).to match a_hash_including("registration_default_collection_sim" => ["druid:fz306fj8334"])
      expect(doc).to match a_hash_including('registration_workflow_id_ssim' => ['digitizationWF'])
      expect(doc).to match a_hash_including('use_statement_ssim'  => ['Rights are owned by Stanford University Libraries. All Rights Reserved. This work is protected by copyright law. No part of the materials may be derived, copied, photocopied, reproduced, translated or reduced to any electronic medium or machine readable form, in whole or in part, without specific permission from the copyright holder. To access this content or to request reproduction permission, please send a written request to speccollref@stanford.edu.'])
      expect(doc).to match a_hash_including('copyright_ssim'      => ['Additional copyright info'])
      expect(doc).to match a_hash_including('default_use_license_machine_ssi' => 'by-nc-sa')
    end
  end
end
