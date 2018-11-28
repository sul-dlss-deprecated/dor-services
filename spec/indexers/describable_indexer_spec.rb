# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::DescribableIndexer do
  let(:model) do
    Class.new(Dor::Abstract) do
      include Dor::Identifiable
      include Dor::Describable
      include Dor::Processable
      # def self.name
      #   'foo'
      # end
    end
  end
  before { stub_config }
  after { unstub_config }

  let(:obj) { instantiate_fixture('druid:ab123cd4567', model) }

  let(:indexer) do
    described_class.new(resource: obj)
  end

  describe '#to_solr' do
    let(:doc) { indexer.to_solr }

    before do
      obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
      allow(obj).to receive(:milestones).and_return({})
    end

    it 'includes values from stanford_mods' do
      # require 'pp'; pp doc
      expect(doc).to match a_hash_including(
        'sw_language_ssim'            => ['English'],
        'sw_language_tesim'           => ['English'],
        'sw_format_ssim'              => ['Book'],
        'sw_format_tesim'             => ['Book'],
        'sw_subject_temporal_ssim'    => ['1800-1900'],
        'sw_subject_temporal_tesim'   => ['1800-1900'],
        'sw_pub_date_sort_ssi'        => '1911',
        'sw_pub_date_sort_isi'        => 1911,
        'sw_pub_date_facet_ssi'       => '1911'
      )
    end

    it 'does not include empty values' do
      doc.keys.sort_by(&:to_s).each do |k|
        expect(doc).to include(k)
        expect(doc).to match hash_excluding(k => nil)
        expect(doc).to match hash_excluding(k => [])
      end
    end
  end
end
