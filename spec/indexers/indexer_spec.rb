# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::CompositeIndexer do
  let(:model) do
    Dor::Abstract
  end
  before { stub_config }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', model) }
  let(:indexer) do
    described_class.new(
      Dor::DescribableIndexer,
      Dor::IdentifiableIndexer,
      Dor::ProcessableIndexer
    )
  end

  describe 'to_solr' do
    context 'with mods stuff' do
      before do
        allow_any_instance_of(Dor::StatusService).to receive(:milestones).and_return({})
        obj.datastreams['descMetadata'].content = read_fixture('bs646cd8717_mods.xml')
      end

      let(:doc) { indexer.new(resource: obj).to_solr }

      it 'searchworks date-fu: temporal periods and pub_dates' do
        expect(doc).to match a_hash_including(
          'sw_subject_temporal_ssim' => a_collection_containing_exactly('18th century', '17th century'),
          'sw_subject_temporal_tesim' => a_collection_containing_exactly('18th century', '17th century'),
          'sw_pub_date_sort_ssi' => '1600',
          'sw_pub_date_sort_isi' => 1600,
          'sw_pub_date_facet_ssi' => '1600'
        )
      end

      it 'subject geographic fields' do
        expect(doc).to match a_hash_including(
          'sw_subject_geographic_ssim' => %w(Europe Europe),
          'sw_subject_geographic_tesim' => %w(Europe Europe)
        )
      end

      it 'genre fields' do
        genre_list = obj.stanford_mods.sw_genre
        expect(doc).to match a_hash_including(
          'sw_genre_ssim' => genre_list,
          'sw_genre_tesim' => genre_list
        )
      end
    end
  end
end
