# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Shelvable do
  let(:shelvable) { Class.new(ActiveFedora::Base) { include Dor::Shelvable } }

  describe '#shelve' do
    let(:druid) { 'druid:ng782rw8378' }
    let(:work) { shelvable.new(pid: druid) }

    it 'calls the ShelvingService' do
      expect(Deprecation).to receive(:warn)
      expect(Dor::ShelvingService).to receive(:shelve).with(work)
      work.shelve
    end
  end
end
