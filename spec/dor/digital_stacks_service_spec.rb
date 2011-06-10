require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::DigitalStacksService do
  before(:all) do
    Dor::Config.stacks.configure do
      document_cache_storage_root '/home/cache'
  	  document_cache_host 'cache.stanford.edu'
  	  document_cache_user 'user'
    end
  end
  
  describe ".transfer_to_document_store" do

    it "copies the given metadata to the document cache in the Digital Stacks" do
      # See etd-robots EtdAccession::Cacher.save_to_document_store
      Dor::DigitalStacksService.should_receive(:execute).with(/^ssh user@cache.stanford.edu mkdir -p \/home\/cache\/aa\/123\/bb\/4567/)
      Dor::DigitalStacksService.should_receive(:execute).with(/^scp ".*" user@cache.stanford.edu:\/home\/cache\/aa\/123\/bb\/4567\/someMd/)
      
      Dor::DigitalStacksService.transfer_to_document_store('druid:aa123bb4567', '<xml/>', 'someMd')
    end
  end
  
  describe ".druid_tree" do
    it "creates a druid tree path from a given druid" do
      path = Dor::DigitalStacksService.druid_tree('druid:aa123bb4567')
      path.should == 'aa/123/bb/4567'
    end
  end
  
end