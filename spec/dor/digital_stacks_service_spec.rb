require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'moab_stanford'
require 'dor/services/digital_stacks_service'

describe Dor::DigitalStacksService do


  before(:each) do
    @content_diff_reports = Pathname('spec').join('fixtures','content_diff_reports')

    inventory_diff_xml = @content_diff_reports.join('gj643zf5650-v3-v4.xml')
    inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml.read)
    @gj643zf5650_content_diff = inventory_diff.group_difference("content")

    inventory_diff_xml = @content_diff_reports.join('jq937jp0017-v1-v2.xml')
    inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml.read)
    @jq937jp0017_content_diff = inventory_diff.group_difference("content")

    inventory_diff_xml = @content_diff_reports.join('ng782rw8378-v3-v4.xml')
    inventory_diff = Moab::FileInventoryDifference.parse(inventory_diff_xml.read)
    @ng782rw8378_content_diff = inventory_diff.group_difference("content")
  end

  describe ".remove_from_stacks" do
    it "deletes content from the digital stacks by druid and file names" do
      s = Pathname("/s")

      content_diff = @gj643zf5650_content_diff
      delete_list = get_delete_list(content_diff)
      expect(delete_list.map { |file| file[0, 2] }).to eq([[:deleted, "page-3.jpg"]])
      delete_list.each do |change_type, filename, signature|
        expect(Dor::DigitalStacksService).to receive(:delete_file).with(s.join(filename), signature)
      end
      Dor::DigitalStacksService.remove_from_stacks(s, content_diff)

      content_diff = @jq937jp0017_content_diff
      delete_list = get_delete_list(content_diff)
      expect(delete_list.map { |file| file[0, 2] }).to eq([
                    [:deleted, "intro-1.jpg"],
                    [:deleted, "intro-2.jpg"],
                    [:modified, "page-1.jpg"]])
      delete_list.each do |change_type, filename, signature|
        expect(Dor::DigitalStacksService).to receive(:delete_file).with(s.join(filename), signature)
      end
      Dor::DigitalStacksService.remove_from_stacks(s, content_diff)

      content_diff = @ng782rw8378_content_diff
      delete_list = get_delete_list(content_diff)
      expect(delete_list.map { |file| file[0, 2] }).to eq([
          [:deleted, "SUB2_b2000_1.bvecs"],
          [:deleted, "SUB2_b2000_1.bvals"],
          [:deleted, "SUB2_b2000_1.nii.gz"]] )
      delete_list.each do |change_type, filename, signature|
        expect(Dor::DigitalStacksService).to receive(:delete_file).with(s.join(filename), signature)
      end
      Dor::DigitalStacksService.remove_from_stacks(s, content_diff)
    end
  end

  def get_delete_list(content_diff)
    delete_list = Array.new
    [:deleted, :copydeleted, :modified].each do |change_type|
      subset = content_diff.subset(change_type) # {Moab::FileGroupDifferenceSubset}
      subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
        moab_signature = moab_file.signatures.first # {Moab::FileSignature}
        delete_list << [change_type, moab_file.basis_path, moab_signature]
      end
    end
    delete_list
  end

  describe ".rename_in_stacks" do
    it "renames content in the digital stacks" do
      s = Pathname("/s")

      content_diff = @gj643zf5650_content_diff
      rename_list = get_rename_list(content_diff)
      expect(rename_list.map { |file| file[0, 3] }).to eq([
            [:renamed, "page-2.jpg", "page-2a.jpg"],
            [:renamed, "page-4.jpg", "page-3.jpg"]])
      rename_list.each do |change_type, oldname, newname, signature|
        tempname = signature.checksums.values.last
        expect(Dor::DigitalStacksService).to receive(:rename_file).with(s.join(oldname), s.join(tempname), signature)
        expect(Dor::DigitalStacksService).to receive(:rename_file).with(s.join(tempname), s.join(newname), signature)
      end
      Dor::DigitalStacksService.rename_in_stacks(s, content_diff)

      content_diff = @jq937jp0017_content_diff
      rename_list = get_rename_list(content_diff)
      expect(rename_list.map { |file| file[0, 3] }).to eq([])
      expect{Dor::DigitalStacksService.rename_in_stacks(s, content_diff)}.not_to raise_error

      content_diff = @ng782rw8378_content_diff
      rename_list = get_rename_list(content_diff)
      expect(rename_list.map { |file| file[0, 3] }).to eq([
            [:renamed, "SUB2_b2000_2.nii.gz", "SUB2_b2000_1.nii.gz"],
            [:renamed, "SUB2_b2000_2.bvecs", "SUB2_b2000_1.bvecs"]])
      rename_list.each do |change_type, oldname, newname, signature|
        tempname = signature.checksums.values.last
        expect(Dor::DigitalStacksService).to receive(:rename_file).with(s.join(oldname), s.join(tempname), signature)
        expect(Dor::DigitalStacksService).to receive(:rename_file).with(s.join(tempname), s.join(newname), signature)
      end
      Dor::DigitalStacksService.rename_in_stacks(s, content_diff)
    end
  end

  def get_rename_list(content_diff)
    rename_list = Array.new
    subset = content_diff.subset(:renamed) # {Moab::FileGroupDifferenceSubset
    subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
      moab_signature = moab_file.signatures.last # {Moab::FileSignature}
      rename_list << [:renamed, moab_file.basis_path , moab_file.other_path, moab_signature]
    end
    rename_list
  end

  describe ".shelve_to_stacks" do
    it "copies the content to the digital stacks" do
      w = Pathname("/w")
      s = Pathname("/s")

      content_diff = @gj643zf5650_content_diff
      shelve_list = get_shelve_list(content_diff)
      expect(shelve_list.map { |file| file[0, 2] }).to eq([ [:added, "page-4.jpg"] ])
      shelve_list.each do |change_type,filename,signature|
        expect(Dor::DigitalStacksService).to receive(:copy_file).with(w.join(filename), s.join(filename), signature)
      end
      Dor::DigitalStacksService.shelve_to_stacks(w, s ,content_diff)

      content_diff = @jq937jp0017_content_diff
      shelve_list = get_shelve_list(content_diff)
      expect(shelve_list.map { |file| file[0, 2] }).to eq([ [ :modified, "page-1.jpg" ] ])
      shelve_list.each do |change_type,filename,signature|
        expect(Dor::DigitalStacksService).to receive(:copy_file).with(w.join(filename), s.join(filename), signature)
      end
      Dor::DigitalStacksService.shelve_to_stacks(w, s ,content_diff)

      content_diff = @ng782rw8378_content_diff
      shelve_list = get_shelve_list(content_diff)
      expect(shelve_list.map { |file| file[0, 2] }).to eq([
            [:added, "SUB2_b2000_2.bvecs"],
            [:added, "SUB2_b2000_2.nii.gz"],
            [:copyadded, "SUB2_b2000_1.bvals"]])
      shelve_list.each do |change_type,filename,signature|
        expect(Dor::DigitalStacksService).to receive(:copy_file).with(w.join(filename), s.join(filename), signature)
      end
      Dor::DigitalStacksService.shelve_to_stacks(w, s ,content_diff)
    end
  end

  def get_shelve_list(content_diff)
    shelve_list = Array.new
    [:added, :copyadded, :modified,].each do |change_type|
      subset = content_diff.subset(change_type) # {Moab::FileGroupDifferenceSubset
      subset.files.each do |moab_file| # {Moab::FileInstanceDifference}
        moab_signature = moab_file.signatures.last # {Moab::FileSignature}
        filename = (change_type == :modified) ? moab_file.basis_path : moab_file.other_path
        shelve_list << [change_type, filename, moab_signature]
      end
    end
    shelve_list
  end

end

describe "file operations" do

  before(:all) do
    @tmpdir = Pathname(Dir.mktmpdir("stacks"))
  end

  after(:all) do
    @tmpdir.rmtree if @tmpdir.exist?
  end

  describe ".delete_file" do
    it "should delete a file, but only if it exists and matches the expected signature" do
      # if file does not exist
      file_pathname = @tmpdir.join('delete-me.txt')
      moab_signature = Moab::FileSignature.new
      expect(file_pathname.exist?).to be_falsey
      expect(Dor::DigitalStacksService.delete_file(file_pathname,moab_signature)).to be_falsey
      # if file exists, but has unexpected signature
      FileUtils.touch(file_pathname.to_s)
      expect(file_pathname.exist?).to be_truthy
      expect(Dor::DigitalStacksService.delete_file(file_pathname,moab_signature)).to be_falsey
      expect(file_pathname.exist?).to be_truthy
      # if file exists, and has expected signature
      moab_signature = Moab::FileSignature.new.signature_from_file(file_pathname)
      expect(Dor::DigitalStacksService.delete_file(file_pathname,moab_signature)).to be_truthy
      expect(file_pathname.exist?).to be_falsey
    end
  end

  describe ".rename_file" do
    it "should rename a file, but only if it exists and has the expected signature" do
      # if file does not exist
      old_pathname = @tmpdir.join('rename-me.txt')
      new_pathname = @tmpdir.join('new-name.txt')
      moab_signature = Moab::FileSignature.new
      expect(old_pathname.exist?).to be_falsey
      expect(new_pathname.exist?).to be_falsey
      expect(Dor::DigitalStacksService.rename_file(old_pathname,new_pathname, moab_signature)).to be_falsey
      # if file exists, but has unexpected signature
      FileUtils.touch(old_pathname.to_s)
      expect(old_pathname.exist?).to be_truthy
      expect(Dor::DigitalStacksService.rename_file(old_pathname,new_pathname, moab_signature)).to be_falsey
      expect(old_pathname.exist?).to be_truthy
      expect(new_pathname.exist?).to be_falsey
      # if file exists, and has expected signature
      moab_signature = Moab::FileSignature.new.signature_from_file(old_pathname)
      expect(Dor::DigitalStacksService.rename_file(old_pathname,new_pathname, moab_signature)).to be_truthy
      expect(old_pathname.exist?).to be_falsey
      expect(new_pathname.exist?).to be_truthy
    end
  end

  describe ".copy_file" do
    it "should copy a file to stacks, but only if it does not yet exist with the expected signature" do
      # if file does not exist in stacks
      workspace_pathname = @tmpdir.join('copy-me.txt')
      stacks_pathname = @tmpdir.join('stacks-name.txt')
      FileUtils.touch(workspace_pathname.to_s)
      moab_signature = Moab::FileSignature.new.signature_from_file(workspace_pathname)
      expect(workspace_pathname.exist?).to be_truthy
      expect(stacks_pathname.exist?).to be_falsey
      expect(Dor::DigitalStacksService.copy_file(workspace_pathname,stacks_pathname, moab_signature)).to be_truthy
      # if file exists, and has expected signature
      expect(workspace_pathname.exist?).to be_truthy
      expect(stacks_pathname.exist?).to be_truthy
      moab_signature = Moab::FileSignature.new.signature_from_file(stacks_pathname)
      expect(Dor::DigitalStacksService.copy_file(workspace_pathname,stacks_pathname, moab_signature)).to be_falsey
      # if file exists, but has unexpected signature
      moab_signature = Moab::FileSignature.new
      expect(workspace_pathname.exist?).to be_truthy
      expect(stacks_pathname.exist?).to be_truthy
      expect(Dor::DigitalStacksService.copy_file(workspace_pathname,stacks_pathname, moab_signature)).to be_truthy
    end
  end

end

describe "depricated Dor::DigitalStacksService" do

  let(:purl_root) { Dir.mktmpdir }
  let(:stacks_root) { Dir.mktmpdir }
  let(:workspace_root) { Dir.mktmpdir }

  before(:each) do
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
