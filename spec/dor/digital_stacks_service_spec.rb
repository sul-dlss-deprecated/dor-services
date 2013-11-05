require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::DigitalStacksService do

  let(:purl_root) { Dir.mktmpdir }
  let(:stacks_root) { Dir.mktmpdir }
  let(:workspace_root) { Dir.mktmpdir }

  before(:each) do
    @mock_ssh  = double(Net::SSH)
    @mock_sftp = double(Net::SFTP)
    Dor::Config.push! {|c| c.stacks.local_document_cache_root purl_root}
    Dor::Config.push! {|c| c.stacks.local_stacks_root stacks_root}
    Dor::Config.push! {|c| c.stacks.local_workspace_root workspace_root}

  end

  after(:each) do
    FileUtils.remove_entry purl_root
    FileUtils.remove_entry stacks_root
    FileUtils.remove_entry workspace_root
    Dor::Config.pop!
  end

  describe ".transfer_to_document_store" do

    it "copies the given metadata to the document cache in the Digital Stacks" do
      dr = DruidTools::PurlDruid.new 'druid:aa123bb4567', purl_root
      item_root = dr.path(nil,true)
      Dor::DigitalStacksService.transfer_to_document_store('druid:aa123bb4567', '<xml/>', 'someMd')
      file_path = dr.find_content('someMd')
      expect(file_path).to match(/4567\/someMd$/)
      expect(IO.read(file_path)).to eq('<xml/>')
    end

  end

  describe ".shelve_to_stacks" do
    it "copies the content to the digital stacks" do
      dr = DruidTools::Druid.new 'druid:aa123bb4567', workspace_root
      File.open(File.join(dr.content_dir, '1.jpg'), 'w') {|f| f.write 'junk'}
      File.open(File.join(dr.content_dir, '2.pdf'), 'w') {|f| f.write 'junk'}

      Dor::DigitalStacksService.shelve_to_stacks 'druid:aa123bb4567', ['1.jpg', '2.pdf']
      dr = DruidTools::StacksDruid.new 'druid:aa123bb4567', stacks_root
      expect(dr.find_content('1.jpg')).to match(/4567\/1.jpg$/)
      expect(dr.find_content('2.pdf')).to match(/4567\/2.pdf$/)
    end


  end

  describe "rename_in_stacks" do
    let(:dr) { DruidTools::StacksDruid.new 'druid:aa123bb4567', stacks_root }
    let(:item_root) { dr.path(nil,true) }

    it "renames content in the digital stacks" do
      File.open(File.join(item_root, '1.jpg'), 'w') {|f| f.write 'junk'}

      files_to_rename = [['1.jpg','2.jpg']]
      Dor::DigitalStacksService.rename_in_stacks('druid:aa123bb4567', files_to_rename)
      expect(dr.find_content('1.jpg')).to be_nil
      expect(File).to exist(dr.find_content('2.jpg'))
    end
  end

  describe ".remove_from_stacks" do
    let(:dr) { DruidTools::StacksDruid.new 'druid:aa123bb4567', stacks_root }
    let(:item_root) { dr.path(nil,true) }
    let(:files_to_remove) { ['1.jpg', '2.pdf'] }

    it "deletes content from the digital stacks by druid and file names" do
      File.open(File.join(item_root, '1.jpg'), 'w') {|f| f.write 'junk'}
      File.open(File.join(item_root, '2.pdf'), 'w') {|f| f.write 'junk'}

      Dor::DigitalStacksService.remove_from_stacks('druid:aa123bb4567', files_to_remove)
      expect(dr.find_content('1.jpg')).to be_nil
      expect(dr.find_content('2.pdf')).to be_nil
    end

    it "skips files that do not exist without raising an exception" do
      File.open(File.join(item_root, '2.pdf'), 'w') {|f| f.write 'junk'}

      Dor::DigitalStacksService.remove_from_stacks('druid:aa123bb4567', files_to_remove)
      expect(dr.find_content('2.pdf')).to be_nil
    end
  end

  describe ".prune_stacks_dir" do
    it "prunes the stacks directory" do
      dr = DruidTools::StacksDruid.new 'druid:aa123bb4567', stacks_root
      item_root = dr.path(nil,true)
      File.open(File.join(item_root, 'somefile'), 'w') {|f| f.write 'junk'}

      Dor::DigitalStacksService.prune_stacks_dir 'druid:aa123bb4567'
      item_pathname = Pathname item_root
      expect(File).to_not exist(item_pathname)
      expect(File).to_not exist(item_pathname.parent)
    end
  end

end
