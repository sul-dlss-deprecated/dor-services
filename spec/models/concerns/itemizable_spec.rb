# frozen_string_literal: true

require 'spec_helper'

class ItemizableItem < ActiveFedora::Base
  include Dor::Itemizable
  include Dor::Processable
end

describe Dor::Itemizable do
  before(:each) { stub_config   }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:bb046xn0881', ItemizableItem)
  end

  it 'has a contentMetadata datastream' do
    expect(@item.contentMetadata).to be_a(Dor::ContentMetadataDS)
  end

  it 'will run get_content_diff' do
    expect(Sdr::Client).to receive(:get_content_diff)
      .with(@item.pid, @item.contentMetadata.content, :all, nil)
    expect { @item.get_content_diff }.not_to raise_error
  end

  it 'will run get_content_diff without contentMetadata' do
    @item.datastreams.delete 'contentMetadata'
    expect { @item.get_content_diff }.to raise_error(Dor::Exception)
  end
end
