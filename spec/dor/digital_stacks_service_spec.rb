require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::DigitalStacksService do
  before(:all) do
    Dor::Config.push! do
      stacks do
        document_cache_storage_root '/home/cache'
    	  document_cache_host 'cache.stanford.edu'
    	  document_cache_user 'user'
	    
    	  storage_root '/stacks'
    	  host 'stacks-test.stanford.edu'
    	  user 'digitaladmin'
	    
    	  local_workspace_root '/workspace'
    	end
    end
    
    @mock_sftp = mock(Net::SFTP)
  end
  
  after(:all) do
    Dor::Config.pop!
  end
  
  describe ".transfer_to_document_store" do

    it "copies the given metadata to the document cache in the Digital Stacks" do
      mock_io = mock('sftp response')
      mock_io.stub(:[]).and_return(mock_io)
      
      Net::SFTP.should_receive(:start).with('cache.stanford.edu','user',kind_of(Hash)).and_yield(@mock_sftp)
      @mock_sftp.should_receive(:session).and_return(@mock_sftp)
      @mock_sftp.should_receive(:'exec!').with("mkdir -p /home/cache/aa/123/bb/4567")
      @mock_sftp.should_receive(:'open!').with("/home/cache/aa/123/bb/4567/someMd",'w').and_yield(mock_io)
      @mock_sftp.should_receive(:'write!').with(mock_io,0,'<xml/>')
      @mock_sftp.should_receive(:'close!').with(mock_io)
      
      Dor::DigitalStacksService.transfer_to_document_store('druid:aa123bb4567', '<xml/>', 'someMd')
    end
  end
  
  describe ".shelve_to_stacks" do
    
    it "copies the content to the digital stacks" do
      Net::SFTP.should_receive(:start).with('stacks-test.stanford.edu','digitaladmin',kind_of(Hash)).and_yield(@mock_sftp)
      @mock_sftp.should_receive(:session).and_return(@mock_sftp)
      @mock_sftp.should_receive(:'exec!').with("mkdir -p /stacks/aa/123/bb/4567")
      @mock_sftp.should_receive(:'upload!').with("/workspace/aa/123/bb/4567/1.jpg","/stacks/aa/123/bb/4567/1.jpg")

      files_to_send = ['1.jpg']
      Dor::DigitalStacksService.shelve_to_stacks('druid:aa123bb4567', files_to_send)
    end
  end
  
  describe ".druid_tree" do
    it "creates a druid tree path from a given druid" do
      path = Dor::DigitalStacksService.druid_tree('druid:aa123bb4567')
      path.should == '/aa/123/bb/4567'
    end
  end
  
end