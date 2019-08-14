# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::IdentityMetadataDS do
  context 'Marshalling to and from a Fedora Datastream' do
    before do
      @dsxml = <<-EOF
        <identityMetadata>
          <objectCreator>DOR</objectCreator>
          <objectId>druid:bb110sm8219</objectId>
          <objectLabel>AMERICQVE | SEPTENTRIONALE</objectLabel>
          <objectType>item</objectType>
          <otherId name="mdtoolkit">bb110sm8219</otherId>
          <otherId name="uuid">b382ee92-da77-11e0-9036-0016034322e4</otherId>
          <sourceId source="sulair">bb110sm8219</sourceId>
          <tag>MDForm : mclaughlin</tag>
          <tag>Project : McLaughlin Maps</tag>
        </identityMetadata>
      EOF

      @dsdoc = described_class.from_xml(@dsxml)
    end

    it 'creates itself from xml' do
      expect(@dsdoc.term_values(:objectId)).to eq(['druid:bb110sm8219'])
      expect(@dsdoc.term_values(:objectType)).to eq(['item'])
      expect(@dsdoc.term_values(:objectLabel)).to eq(['AMERICQVE | SEPTENTRIONALE'])
      expect(@dsdoc.term_values(:tag)).to match_array(['MDForm : mclaughlin', 'Project : McLaughlin Maps'])
      expect(@dsdoc.term_values(:otherId)).to match_array(%w[bb110sm8219 b382ee92-da77-11e0-9036-0016034322e4])
      expect(@dsdoc.term_values(:sourceId)).to eq(['bb110sm8219'])
      expect(@dsdoc.objectId).to eq('druid:bb110sm8219')
      expect(@dsdoc.otherId).to eq(['mdtoolkit:bb110sm8219', 'uuid:b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('mdtoolkit')).to eq(['bb110sm8219'])
      expect(@dsdoc.otherId('uuid')).to eq(['b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('bogus')).to eq([])
      expect(@dsdoc.sourceId).to eq('sulair:bb110sm8219')
    end

    it 'can read ID fields as attributes' do
      expect(@dsdoc.objectId).to eq('druid:bb110sm8219')
      expect(@dsdoc.otherId).to eq(['mdtoolkit:bb110sm8219', 'uuid:b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('mdtoolkit')).to eq(['bb110sm8219'])
      expect(@dsdoc.otherId('uuid')).to eq(['b382ee92-da77-11e0-9036-0016034322e4'])
      expect(@dsdoc.otherId('bogus')).to eq([])
      expect(@dsdoc.sourceId).to eq('sulair:bb110sm8219')
    end

    it 'sets the (stripped) sourceID' do
      resultxml = <<-EOF
        <identityMetadata>
          <objectCreator>DOR</objectCreator>
          <objectId>druid:bb110sm8219</objectId>
          <objectLabel>AMERICQVE | SEPTENTRIONALE</objectLabel>
          <objectType>item</objectType>
          <otherId name="mdtoolkit">bb110sm8219</otherId>
          <otherId name="uuid">b382ee92-da77-11e0-9036-0016034322e4</otherId>
          <sourceId source="test">ab110cd8219</sourceId>
          <tag>MDForm : mclaughlin</tag>
          <tag>Project : McLaughlin Maps</tag>
        </identityMetadata>
      EOF
      @dsdoc.sourceId = ' test:  ab110cd8219  '
      expect(@dsdoc).to be_changed
      expect(@dsdoc.sourceId).to eq('test:ab110cd8219')
      expect(@dsdoc.to_xml).to be_equivalent_to resultxml
    end

    describe 'removes source ID node' do
      let(:resultxml) do
        <<-EOF
          <identityMetadata>
            <objectCreator>DOR</objectCreator>
            <objectId>druid:bb110sm8219</objectId>
            <objectLabel>AMERICQVE | SEPTENTRIONALE</objectLabel>
            <objectType>item</objectType>
            <otherId name="mdtoolkit">bb110sm8219</otherId>
            <otherId name="uuid">b382ee92-da77-11e0-9036-0016034322e4</otherId>
            <tag>MDForm : mclaughlin</tag>
            <tag>Project : McLaughlin Maps</tag>
          </identityMetadata>
        EOF
      end

      it 'on nil' do
        @dsdoc.sourceId = nil
        expect(@dsdoc.sourceId).to be_nil
        expect(@dsdoc.to_xml).to be_equivalent_to resultxml
      end
      it 'on empty string' do
        @dsdoc.sourceId = ''
        expect(@dsdoc.sourceId).to be_nil
        expect(@dsdoc.to_xml).to be_equivalent_to resultxml
      end
    end

    it 'raises ArgumentError on malformed sourceIDs' do
      expect { @dsdoc.sourceId = 'NotEnoughColons' }.to raise_exception(ArgumentError)
      expect { @dsdoc.sourceId = ':EmptyFirstPart' }.to raise_exception(ArgumentError)
      expect { @dsdoc.sourceId = 'WhitespaceSecondPart:  ' }.to raise_exception(ArgumentError)
      expect { @dsdoc.sourceId = 'WhitespaceSecondPart:  ' }.to raise_exception(ArgumentError)
    end

    it 'does not raise error on a sourceId with multiple colons' do
      expect { @dsdoc.sourceId = 'Too:Many:Parts' }.not_to raise_exception
      expect { @dsdoc.sourceId = 'Too::ManyColons' }.not_to raise_exception
    end

    it 'creates a simple default with #new' do
      new_doc = described_class.new nil, 'identityMetadata'
      expect(new_doc.to_xml).to be_equivalent_to '<identityMetadata/>'
    end

    it 'properly adds elements' do
      resultxml = <<-EOF
        <identityMetadata>
          <objectId>druid:ab123cd4567</objectId>
          <otherId name="mdtoolkit">ab123cd4567</otherId>
          <otherId name="uuid">12345678-abcd-1234-ef01-23456789abcd</otherId>
          <tag>Created By : Spec Tests</tag>
        </identityMetadata>
      EOF
      new_doc = described_class.new nil, 'identityMetadata'
      new_doc.add_value('objectId', 'druid:ab123cd4567')
      new_doc.add_value('otherId', '12345678-abcd-1234-ef01-23456789abcd', 'name' => 'uuid')
      new_doc.add_value('otherId', 'ab123cd4567', 'name' => 'mdtoolkit')
      new_doc.add_value('tag', 'Created By : Spec Tests')
      expect(new_doc.to_xml).to be_equivalent_to resultxml
      expect(new_doc.objectId).to eq('druid:ab123cd4567')
      expect(new_doc.otherId).to match_array(['mdtoolkit:ab123cd4567', 'uuid:12345678-abcd-1234-ef01-23456789abcd'])
    end
  end

  describe 'add_other_Id' do
    let(:ds) { instantiate_fixture('druid:ab123cd4567', Dor::Item).identityMetadata }

    before do
      ds.instance_variable_set(:@datastream_content, ds.content)
      allow(ds).to receive(:new?).and_return(false)
    end

    it 'adds an other_id record' do
      ds.add_other_Id('mdtoolkit', 'someid123')
      expect(ds.otherId('mdtoolkit').first).to eq('someid123')
    end

    it 'raises an exception if a record of that type already exists' do
      ds.add_other_Id('mdtoolkit', 'someid123')
      expect(ds.otherId('mdtoolkit').first).to eq('someid123')
      expect { ds.add_other_Id('mdtoolkit', 'someid123') }.to raise_error(RuntimeError)
    end
  end

  describe 'update_other_Id' do
    let(:ds) { instantiate_fixture('druid:ab123cd4567', Dor::Item).identityMetadata }

    before do
      ds.instance_variable_set(:@datastream_content, ds.content)
      allow(ds).to receive(:new?).and_return(false)
    end

    it 'updates an existing id and return true to indicate that it found something to update' do
      ds.add_other_Id('mdtoolkit', 'someid123')
      expect(ds.otherId('mdtoolkit').first).to eq('someid123')
      # return value should be true when it finds something to update
      expect(ds.update_other_Id('mdtoolkit', 'someotherid234', 'someid123')).to be_truthy
      expect(ds).to be_changed
      expect(ds.otherId('mdtoolkit').first).to eq('someotherid234')
    end

    it 'returns false if there was no existing record to update' do
      expect(ds.update_other_Id('mdtoolkit', 'someotherid234')).to be_falsey
    end
  end

  describe 'remove_other_Id' do
    let(:ds) { instantiate_fixture('druid:ab123cd4567', Dor::Item).identityMetadata }

    before do
      ds.instance_variable_set(:@datastream_content, ds.content)
      allow(ds).to receive(:new?).and_return(false)
    end

    it 'removes an existing otherid when the tag and value match' do
      ds.add_other_Id('mdtoolkit', 'someid123')
      expect(ds).to be_changed
      expect(ds.otherId('mdtoolkit').first).to eq('someid123')
      expect(ds.remove_other_Id('mdtoolkit', 'someid123')).to be_truthy
      expect(ds.otherId('mdtoolkit').length).to eq(0)
    end

    it 'returns false if there was nothing to delete' do
      expect(ds.remove_other_Id('mdtoolkit', 'someid123')).to be_falsey
      expect(ds).not_to be_changed
    end
  end
end
