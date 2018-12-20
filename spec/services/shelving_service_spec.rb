# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::ShelvingService do
  let(:shelvable_item) do
    Class.new(ActiveFedora::Base) { include Dor::Itemizable }
  end

  let!(:stacks_root) { Dir.mktmpdir }
  let!(:workspace_root) { Dir.mktmpdir }

  before do
    Dor::Config.push! { |c| c.stacks.local_stacks_root stacks_root }
    Dor::Config.push! { |c| c.stacks.local_workspace_root workspace_root }
  end

  after do
    FileUtils.remove_entry stacks_root
    FileUtils.remove_entry workspace_root
    Dor::Config.pop!
  end
  let(:work) { shelvable_item.new(pid: druid) }
  let(:service) { described_class.new work }

  describe '.shelve' do
    let(:druid) { 'druid:ng782rw8378' }
    let(:mock_diff) { double(Moab::FileGroupDifference) }
    let(:mock_workspace_path) { double(Pathname) }

    before do
      # stub the shelve_diff method which is unit tested below
      expect(service).to receive(:shelve_diff).and_return(mock_diff)
      # stub the workspace_content_dir method which is unit tested below
      expect(service).to receive(:workspace_content_dir).with(mock_diff, an_instance_of(DruidTools::Druid)).and_return(mock_workspace_path)
    end

    it 'pushes file changes for shelve-able files into the stacks' do
      stacks_object_pathname = Pathname(DruidTools::StacksDruid.new(druid, stacks_root).path)
      # make sure the DigitalStacksService is getting the correct delete, rename, and shelve requests
      # (These methods are unit tested in digital_stacks_service_spec.rb)
      expect(Dor::DigitalStacksService).to receive(:remove_from_stacks).with(stacks_object_pathname, mock_diff)
      expect(Dor::DigitalStacksService).to receive(:rename_in_stacks).with(stacks_object_pathname, mock_diff)
      expect(Dor::DigitalStacksService).to receive(:shelve_to_stacks).with(mock_workspace_path, stacks_object_pathname, mock_diff)
      service.send(:shelve)
    end
  end

  describe '#shelve_diff' do
    let(:druid) { 'druid:jq937jp0017' }
    subject(:result) { service.send(:shelve_diff) }

    context 'when contentMetadata exists' do
      it 'retrieves the differences between the current contentMetadata and the previously ingested version' do
        # read in a FileInventoryDifference manifest from the fixtures area
        xml_pathname = Pathname('spec').join('fixtures', 'content_diff_reports', 'jq937jp0017-v1-v2.xml')
        expect(Sdr::Client).to receive(:get_content_diff).with(druid, nil, 'shelve').and_return(Moab::FileInventoryDifference.parse(xml_pathname.read))
        expect(result.to_xml).to be_equivalent_to(<<-XML
          <fileGroupDifference groupId="content" differenceCount="3" identical="3" copyadded="0" copydeleted="0" renamed="0" modified="1" added="0" deleted="2">
            <subset change="identical" count="3">
              <file change="identical" basisPath="page-2.jpg" otherPath="same">
                <fileSignature size="39450" md5="82fc107c88446a3119a51a8663d1e955" sha1="d0857baa307a2e9efff42467b5abd4e1cf40fcd5" sha256="235de16df4804858aefb7690baf593fb572d64bb6875ec522a4eea1f4189b5f0"/>
              </file>
              <file change="identical" basisPath="page-3.jpg" otherPath="same">
                <fileSignature size="19125" md5="a5099878de7e2e064432d6df44ca8827" sha1="c0ccac433cf02a6cee89c14f9ba6072a184447a2" sha256="7bd120459eff0ecd21df94271e5c14771bfca5137d1dd74117b6a37123dfe271"/>
              </file>
              <file change="identical" basisPath="title.jpg" otherPath="same">
                <fileSignature size="40873" md5="1a726cd7963bd6d3ceb10a8c353ec166" sha1="583220e0572640abcd3ddd97393d224e8053a6ad" sha256="8b0cee693a3cf93cf85220dd67c5dc017a7edcdb59cde8fa7b7f697be162b0c5"/>
              </file>
            </subset>
            <subset change="renamed" count="0"/>
            <subset change="modified" count="1">
              <file change="modified" basisPath="page-1.jpg" otherPath="same">
                <fileSignature size="25153" md5="3dee12fb4f1c28351c7482b76ff76ae4" sha1="906c1314f3ab344563acbbbe2c7930f08429e35b" sha256="41aaf8598c9d8e3ee5d55efb9be11c542099d9f994b5935995d0abea231b8bad"/>
                <fileSignature size="32915" md5="c1c34634e2f18a354cd3e3e1574c3194" sha1="0616a0bd7927328c364b2ea0b4a79c507ce915ed" sha256="b78cc53b7b8d9ed86d5e3bab3b699c7ed0db958d4a111e56b6936c8397137de0"/>
              </file>
            </subset>
            <subset change="deleted" count="2">
              <file change="deleted" basisPath="intro-1.jpg" otherPath="">
                <fileSignature size="41981" md5="915c0305bf50c55143f1506295dc122c" sha1="60448956fbe069979fce6a6e55dba4ce1f915178" sha256="4943c6ffdea7e33b74fd7918de900de60e9073148302b0ad1bf5df0e6cec032a"/>
              </file>
              <file change="deleted" basisPath="intro-2.jpg" otherPath="">
                <fileSignature size="39850" md5="77f1a4efdcea6a476505df9b9fba82a7" sha1="a49ae3f3771d99ceea13ec825c9c2b73fc1a9915" sha256="3a28718a8867e4329cd0363a84aee1c614d0f11229a82e87c6c5072a6e1b15e7"/>
              </file>
            </subset>
            <subset change="added" count="0"/>
            <subset change="copyadded" count="0"/>
            <subset change="copydeleted" count="0"/>
          </fileGroupDifference>
        XML
                                                 )
      end
    end

    context 'when contentMetadata does not exist' do
      it 'raises an error' do
        work.datastreams.delete 'contentMetadata'
        expect { result }.to raise_error(Dor::Exception)
      end
    end
  end

  describe '#workspace_content_dir' do
    let(:druid) { 'druid:jq937jp0017' }
    let(:workspace_druid) { DruidTools::Druid.new(druid, Dor::Config.stacks.local_workspace_root) }

    # create an empty workspace location for object content files
    let(:content_dir) { workspace_druid.path('content', true) }

    # read in a FileInventoryDifference manifest from the fixtures area
    let(:content_diff_reports) { Pathname('spec').join('fixtures', 'content_diff_reports') }
    let(:inventory_diff_xml) { content_diff_reports.join('ng782rw8378-v3-v4.xml') }
    let(:inventory_diff) { Moab::FileInventoryDifference.parse(inventory_diff_xml.read) }
    let(:content_diff) { inventory_diff.group_difference('content') }

    subject { service.send(:workspace_content_dir, content_diff, workspace_druid) }
    context 'when the manifest files are not in the workspace' do
      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /content dir not found/)
      end
    end

    context 'when the content files are in the workspace area' do
      before do
        # put the content files in the content_pathname location .../ng/782/rw/8378/ng782rw8378/content
        deltas = content_diff.file_deltas
        filelist = deltas[:modified] + deltas[:added] + deltas[:copyadded].collect { |_old, new| new }
        expect(filelist).to eq(['SUB2_b2000_2.bvecs', 'SUB2_b2000_2.nii.gz', 'SUB2_b2000_1.bvals'])
        filelist.each { |file| FileUtils.touch(File.join(content_dir, file)) }
      end

      it { is_expected.to eq Pathname(content_dir) }

      context 'when the content files are up a directory to .../ng/782/rw/8378/ng782rw8378' do
        let(:content_dir) { workspace_druid.path(nil, true) }

        it { is_expected.to eq Pathname(content_dir) }
      end

      context 'when the content files are up a dreictory to .../ng/782/rw/8378' do
        let(:content_dir) { Pathname(workspace_druid.path(nil, true)).parent }

        it { is_expected.to eq Pathname(content_dir) }
      end
    end
  end

  describe '#stacks_location' do
    let(:druid) { 'druid:xy123xy1234' }
    subject(:location) { service.send(:stacks_location) }
    it 'returns the default stack' do
      work.contentMetadata.content = '<contentMetadata/>'
      expect(location).to eq stacks_root
    end

    it 'returns the absolute stack' do
      work.contentMetadata.content = '<contentMetadata stacks="/specialstacks"/>'
      expect(location).to eq '/specialstacks'
    end

    it 'returns a relative stack' do
      work.contentMetadata.content = '<contentMetadata stacks="specialstacks"/>'
      expect { location }.to raise_error(RuntimeError)
    end
  end
end
