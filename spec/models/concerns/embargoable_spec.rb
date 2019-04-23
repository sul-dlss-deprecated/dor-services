# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Embargoable do
  let(:service) do
    instance_double(Dor::EmbargoService,
                    update: true,
                    release: true,
                    release_20_pct_vis: true)
  end
  let(:embargo_item) { Dor::Item.new }

  before do
    allow(Dor::EmbargoService).to receive(:new).and_return(service)
  end

  describe '#release_embargo' do
    it 'delegates to the EmbargoService' do
      embargo_item.release_embargo('application:embargo-release')
      expect(service).to have_received(:release).with('application:embargo-release')
    end
  end

  describe '#release_20_pct_vis_embargo' do
    it 'delegates to the EmbargoService' do
      embargo_item.release_20_pct_vis_embargo('application:embargo-release')
      expect(service).to have_received(:release_20_pct_vis).with('application:embargo-release')
    end
  end

  describe '#update_embargo' do
    let(:time) { Time.now.utc + 1.month }

    it 'delegates to the EmbargoService' do
      embargo_item.update_embargo(time)
      expect(service).to have_received(:update).with(time)
    end
  end
end
