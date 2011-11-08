require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'dor-services'

describe Dor do
  before :each do
    Dor.configure do
      fedora do
        url 'http://fedoraAdmin:fedoraPass@dor.edu/fedora'
      end

      suri do
        mint_ids true
        id_namespace 'test'
        url 'http://suri.dor.edu:8080'
        user 'suri-user'
        pass 'suri-pass'
      end

      metadata do
        exist.url 'http://existUser:existPass@exist.dor.edu/exist/rest/'
        catalog.url 'http://catalog.dor.edu/catalog/mods'
      end

      gsearch.url 'http://dor.edu/solr'
      workflow.url 'https://workflow.dor.edu/workflow/'
    end
  end
  
  it "should reload all modules" do
    old_config = Dor::Config.to_hash
    Dor.reload!.should == Dor
    Dor::Config.to_hash.should == old_config
  end
end