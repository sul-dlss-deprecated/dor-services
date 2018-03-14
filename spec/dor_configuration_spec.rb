require 'spec_helper'

RSpec.describe Dor::Configuration do
  let(:config) do
    Dor::Configuration.new(YAML.load(File.read(File.expand_path('../config/config_defaults.yml', __dir__))))
  end

  it 'configures the Dor::WorkflowService when Dor::Config.configure is called' do
    config.configure do
      workflow.url 'http://mynewurl.edu/workflow'
    end

    expect(config.workflow.client.base_url.to_s).to eq('http://mynewurl.edu/workflow')
  end

  it 'adds deprecation warnings for old solrizer configurations' do
    config.solr.url = nil
    expect(ActiveSupport::Deprecation).to receive(:warn)
    config.configure do
      solrizer.url 'http://example.com/solr'
    end
    expect(config.solr.url).to eq 'http://example.com/solr'
  end
end
