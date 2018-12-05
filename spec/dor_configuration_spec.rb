# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Configuration do
  let(:config) do
    described_class.new(YAML.load(File.read(File.expand_path('../config/config_defaults.yml', __dir__))))
  end

  it 'configures the Dor::WorkflowService when Dor::Config.configure is called' do
    config.configure do
      workflow.url 'http://mynewurl.edu/workflow'
    end

    expect(config.workflow.client.base_url.to_s).to eq('http://mynewurl.edu/workflow')
  end
end
