# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Etd do
  let(:etd) do
    described_class.new
  end

  describe '#to_solr' do
    subject { etd.to_solr }

    let(:wf_indexer) { instance_double(Dor::WorkflowsIndexer, to_solr: {}) }
    let(:process_indexer) { instance_double(Dor::ProcessableIndexer, to_solr: {}) }

    before do
      allow(Dor::WorkflowsIndexer).to receive(:new).and_return(wf_indexer)
      allow(Dor::ProcessableIndexer).to receive(:new).and_return(process_indexer)
    end

    it { is_expected.to be_a_kind_of Hash }
  end

  describe '#etd_embargo_date' do
    it 'calculates the data of the embargo release' do
      t = Time.now.beginning_of_hour
      etd.datastreams['properties'].regactiondttm = [t.strftime('%m/%d/%Y %H:%M:%S')]
      etd.datastreams['properties'].regapproval = ['approved']
      etd.datastreams['properties'].embargo = ['6 months']

      expect(etd.etd_embargo_date).to eq t + 6.months
    end
  end

  it 'handles the Term element' do
    props_ds = etd.datastreams['properties']
    expect(props_ds).to respond_to(:term_values)
  end

  it 'handles the <sub> element' do
    props_ds = etd.datastreams['properties']
    expect(props_ds.sub.to_a).to be_empty
  end

  it 'has an events datastream' do
    events = etd.datastreams['events']
    expect(events).to be_a_kind_of Dor::EventsDS
  end

  it 'has an embargoMetadata datastream' do
    eds = etd.datastreams['embargoMetadata']
    expect(eds).to be_a_kind_of Dor::EmbargoMetadataDS
  end
end
