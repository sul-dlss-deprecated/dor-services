# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Configuration do
  let(:config) do
    described_class.new(YAML.load(File.read(File.expand_path('../config/config_defaults.yml', __dir__))))
  end

  describe '.workflow.client' do
    context 'when Dor::Config.configure is called' do
      subject { config.workflow.client.requestor.send(:base_url) }

      before do
        config.configure do
          workflow.url 'http://mynewurl.edu/workflow'
        end
      end

      it { is_expected.to eq URI('http://mynewurl.edu/workflow') }
    end
  end
end
