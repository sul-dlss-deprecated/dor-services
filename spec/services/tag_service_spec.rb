# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::TagService do
  let(:item) do
    item = instantiate_fixture('druid:ab123cd4567', Dor::Item)
    allow(item).to receive(:new?).and_return(false)
    ds = item.identityMetadata
    ds.instance_variable_set(:@datastream_content, item.identityMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    item
  end

  # when looking for tags after addition/update/removal, check for the normalized form.
  # when doing the add/update/removal, specify the tag in non-normalized form so that the
  # normalization mechanism actually gets tested.
  describe '.add' do
    subject(:add) { described_class.add(item, 'sometag:someval') }

    it 'adds a new tag' do
      add
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end

    it 'raises an exception if there is an existing tag like it' do
      described_class.add(item, 'sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect { add }.to raise_error(RuntimeError)
    end
  end

  describe '.update' do
    subject(:update) { described_class.update(item, 'sometag :someval', 'new :tag') }

    it 'updates a tag' do
      described_class.add(item, 'sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(update).to be_truthy
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_falsey
      expect(item.identityMetadata.tags.include?('new : tag')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end

    it 'returns false if there is no matching tag to update' do
      expect(update).to be_falsey
      expect(item.identityMetadata).not_to be_changed
    end
  end

  describe '.remove' do
    subject(:remove) { described_class.remove(item, 'sometag:someval') }

    it 'deletes a tag' do
      described_class.add(item, 'sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(remove).to be_truthy
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_falsey
      expect(item.identityMetadata).to be_changed
    end
  end

  describe '#validate_and_normalize_tag' do
    let(:service) { described_class.new(item) }
    subject(:invoke) { service.send(:validate_and_normalize_tag, tag_str, existing_tags) }
    let(:existing_tags) { [] }

    context 'when the tag has too few elements' do
      let(:tag_str) { 'just one part' }

      it 'throws an exception' do
        expect { invoke }.to raise_error(ArgumentError, "Invalid tag structure: tag '#{tag_str}' must have at least 2 elements")
      end
    end

    context 'when the tag has empty elements' do
      let(:tag_str) { 'test part1 :  : test part3' }

      it 'throws an exception' do
        expect { invoke }.to raise_error(ArgumentError, "Invalid tag structure: tag '#{tag_str}' contains empty elements")
      end
    end

    context 'when the tag is the same as an existing tag' do
      let(:tag_str) { 'another:multi:part:test' }
      let(:existing_tags) { ['test part1 : test part2', 'Another : Multi : Part : Test', 'one : last_tag'] }

      it 'throws an exception' do
        # note that tag_str should match existing_tags[1] because the comparison should happen after normalization, and it should
        # be case-insensitive.
        expect { invoke }.to raise_error(RuntimeError, "An existing tag (#{existing_tags[1]}) is the same, consider using update_tag?")
      end
    end
  end
end
