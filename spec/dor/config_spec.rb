require 'spec_helper'

describe Dor::Configuration do

  before :each do
    @config = Dor::Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__))))
  end

  it 'should issue a deprecation warning if SSL options are passed to the fedora block' do
    expect(ActiveSupport::Deprecation).to receive(:warn).with(/fedora.cert_file/, instance_of(Array))
    expect(ActiveSupport::Deprecation).to receive(:warn).with(/fedora.key_file/, instance_of(Array))
    @config.configure do
      fedora do
        cert_file 'my_cert_file'
        key_file 'my_key_file'
      end
    end
  end

  it 'should move SSL options from the fedora block to the ssl block' do
    ActiveSupport::Deprecation.silence do
      @config.configure do
        fedora do
          cert_file 'my_cert_file'
          key_file 'my_key_file'
        end
      end
    end
    expect(@config.ssl).to eq({ :cert_file => 'my_cert_file', :key_file => 'my_key_file', :key_pass => '' })
    expect(@config.fedora).not_to include(:cert_file)
  end

  it 'configures the Dor::WorkflowService when Dor::Config.configure is called' do
    @config.configure do
      workflow.url 'http://mynewurl.edu/workflow'
    end

    expect(Dor::WorkflowService.workflow_resource.to_s).to eq('http://mynewurl.edu/workflow')
  end

  it 'adds deprecation warnings for old solrizer configurations' do
    @config.solr.url = nil
    expect(ActiveSupport::Deprecation).to receive(:warn)
    @config.configure do
      solrizer.url 'http://example.com/solr'
    end
    expect(@config.solr.url).to eq 'http://example.com/solr'
  end
end
