require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::Configuration do
  
  before :each do
    @config = Dor::Configuration.new(YAML.load(File.read(File.expand_path('../../../config/config_defaults.yml', __FILE__))))
  end
  
  it "should issue a deprecation warning if SSL options are passed to the fedora block" do
    ActiveSupport::Deprecation.should_receive(:warn).with(/fedora.cert_file/, instance_of(Array))
    ActiveSupport::Deprecation.should_receive(:warn).with(/fedora.key_file/, instance_of(Array))
    @config.configure do
      fedora do
        cert_file 'my_cert_file'
        key_file 'my_key_file'
      end
    end
  end

  it "should move SSL options from the fedora block to the ssl block" do
    ActiveSupport::Deprecation.silence do
      @config.configure do
        fedora do
          cert_file 'my_cert_file'
          key_file 'my_key_file'
        end
      end
    end
    @config.ssl.should == { :cert_file => 'my_cert_file', :key_file => 'my_key_file', :key_pass => '' }
    @config.fedora.has_key?(:cert_file).should == false
  end
  
  it "#sanitize" do
    Dor::Config.should have_key(:ssl)
    Dor::Config[:ssl].should_not be_empty
    Dor::Config[:sdr].should have_key(:local_workspace_root)

    config = Dor::Config.sanitize
    config[:ssl].should be_empty
    config[:sdr].should_not have_key(:local_workspace_root)
  end
  
  it "#autoconfigure" do
    FakeWeb.register_uri :get, 'http://example.edu/dor-configuration', :body => Dor::Config.sanitize.to_json
    @config.fedora.url.should be_nil
    @config.autoconfigure('http://example.edu/dor-configuration')
    @config.fedora.url.should_not be_nil
    @config.fedora.url.should == Dor::Config.fedora.url
    @config.fedora.client.should be_a(RestClient::Resource)
  end
end
