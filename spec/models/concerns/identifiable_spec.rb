require 'spec_helper'

class IdentifiableItem < ActiveFedora::Base
  include Dor::Identifiable
end

describe Dor::Identifiable do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before(:all) do
    @mock_rel_druid = 'druid:does_not_exist'
    @mock_rels_ext_xml = %(<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
              <hydra:isGovernedBy rdf:resource="info:fedora/#{@mock_rel_druid}"/>
              <fedora:isMemberOfCollection rdf:resource="info:fedora/#{@mock_rel_druid}"/>
            </rdf:Description>
          </rdf:RDF>)
  end

  let(:item) do
    item = instantiate_fixture('druid:ab123cd4567', IdentifiableItem)
    allow(item).to receive(:new?).and_return(false)
    ds = item.identityMetadata
    ds.instance_variable_set(:@datastream_content, item.identityMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    item
  end

  it 'should have an identityMetadata datastream' do
    expect(item.datastreams['identityMetadata']).to be_a(Dor::IdentityMetadataDS)
  end

  it 'source_id fetches from IdentityMetadata' do
    expect(item.source_id).to eq('google:STANFORD_342837261527')
    expect(item.source_id).to eq(item.identityMetadata.sourceId)
  end

  describe 'source_id= (AKA set_source_id)' do
    it 'raises on unsalvageable values' do
      expect{item.source_id = 'NotEnoughColons'}.to raise_error ArgumentError
      expect{item.source_id = ':EmptyFirstPart'}.to raise_error ArgumentError
      expect{item.source_id = 'WhitespaceSecondPart:   '}.to raise_error ArgumentError
    end
    it 'should set the source_id' do
      item.source_id = 'fake:sourceid'
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
    end
    it 'should replace the source_id if one exists' do
      item.source_id = 'fake:sourceid'
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
      item.source_id = 'new:sourceid2'
      expect(item.identityMetadata.sourceId).to eq('new:sourceid2')
    end
    it 'should do normalization via identityMetadata.sourceID=' do
      item.source_id = ' SourceX :  Value Y  '
      expect(item.source_id).to eq('SourceX:Value Y')
    end
    it 'allows colons in the value' do
      item.source_id = 'one:two:three'
      expect(item.source_id).to eq('one:two:three')
      item.source_id = 'one::two::three'
      expect(item.source_id).to eq('one::two::three')
    end
    it 'should delete the sourceId node on nil or empty-string' do
      item.source_id = nil
      expect(item.source_id).to be_nil
      item.source_id = 'fake:sourceid'
      expect(item.source_id).to eq('fake:sourceid')
      item.source_id = ''
      expect(item.source_id).to be_nil
    end
  end

  describe 'add_other_Id' do
    it 'should add an other_id record' do
      item.add_other_Id('mdtoolkit', 'someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
    end
    it 'should raise an exception if a record of that type already exists' do
      item.add_other_Id('mdtoolkit', 'someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      expect{item.add_other_Id('mdtoolkit', 'someid123')}.to raise_error(RuntimeError)
    end
  end

  describe 'update_other_Id' do
    it 'should update an existing id and return true to indicate that it found something to update' do
      item.add_other_Id('mdtoolkit', 'someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      # return value should be true when it finds something to update
      expect(item.update_other_Id('mdtoolkit', 'someotherid234', 'someid123')).to be_truthy
      expect(item.identityMetadata).to be_changed
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someotherid234')
    end
    it 'should return false if there was no existing record to update' do
      expect(item.update_other_Id('mdtoolkit', 'someotherid234')).to be_falsey
    end
  end

  describe 'remove_other_Id' do
    it 'should remove an existing otherid when the tag and value match' do
      item.add_other_Id('mdtoolkit', 'someid123')
      expect(item.identityMetadata).to be_changed
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      expect(item.remove_other_Id('mdtoolkit', 'someid123')).to be_truthy
      expect(item.identityMetadata.otherId('mdtoolkit').length).to eq(0)
    end
    it 'should return false if there was nothing to delete' do
      expect(item.remove_other_Id('mdtoolkit', 'someid123')).to be_falsey
      expect(item.identityMetadata).not_to be_changed
    end
    it 'should affect identity_metadata_source computation' do
      item.remove_other_Id('catkey', '129483625')
      item.remove_other_Id('barcode', '36105049267078')
      item.add_other_Id('catkey', '129483625')
      expect(item.identity_metadata_source).to eq 'Symphony'
      item.remove_other_Id('catkey', '129483625')
      item.add_other_Id('barcode', '36105049267078')
      expect(item.identity_metadata_source).to eq 'Symphony'
      item.remove_other_Id('barcode', '36105049267078')
      expect(item.identity_metadata_source).to eq 'DOR'
      item.remove_other_Id('foo', 'bar')
      expect(item.identity_metadata_source).to eq 'DOR'
      expect(item.identityMetadata).to be_changed
    end
  end

  # when looking for tags after addition/update/removal, check for the normalized form.
  # when doing the add/update/removal, specify the tag in non-normalized form so that the
  # normalization mechanism actually gets tested.
  describe 'add_tag' do
    it 'should add a new tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end
    it 'should raise an exception if there is an existing tag like it' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect {item.add_tag('sometag: someval')}.to raise_error(RuntimeError)
    end
  end

  describe 'update_tag' do
    it 'should update a tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(item.update_tag('sometag :someval', 'new :tag')).to be_truthy
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_falsey
      expect(item.identityMetadata.tags.include?('new : tag')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end
    it 'should return false if there is no matching tag to update' do
      expect(item.update_tag('sometag:someval', 'new:tag')).to be_falsey
      expect(item.identityMetadata).not_to be_changed
    end
  end

  describe 'remove_druid_prefix' do
    it 'should remove the druid prefix if it is present' do
      expect(item.remove_druid_prefix).to eq('ab123cd4567')
    end

    it 'should remove the druid prefix for an arbitrary druid passed in' do
      expect(item.remove_druid_prefix('druid:oo000oo0001')).to eq('oo000oo0001')
    end

    it 'should leave the string unchanged if the druid prefix is already stripped' do
      expect(item.remove_druid_prefix('oo000oo0001')).to eq('oo000oo0001')
    end

    it 'should just return the input string if there are no matches' do
      expect(item.remove_druid_prefix('bogus')).to eq('bogus')
    end
  end

  describe 'regex' do
    it 'should identify pids by regex' do
      expect('ab123cd4567'.match(item.pid_regex).size).to eq(1)
    end
    it 'should pull out a pid by regex' do
      expect('druid:ab123cd4567/other crappola'.match(item.pid_regex)[0]).to eq("ab123cd4567")
    end
    it 'should not identify non-pids' do
      expect('bogus'.match(item.pid_regex)).to be_nil
    end
    it 'should not identify pid by druid regex' do
      expect('ab123cd4567'.match(item.druid_regex)).to be_nil
    end
    it 'should identify full druid by regex' do
      expect('druid:ab123cd4567'.match(item.druid_regex).size).to eq(1)
    end
    it 'should pull out a full druid by regex' do
      expect('druid:ab123cd4567/other crappola'.match(item.druid_regex)[0]).to eq("druid:ab123cd4567")
    end
    it 'should not identify non-druids' do
      expect('bogus'.match(item.druid_regex)).to be_nil
    end
  end

  describe 'remove_tag' do
    it 'should delete a tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_truthy
      expect(item.remove_tag('sometag:someval')).to be_truthy
      expect(item.identityMetadata.tags.include?('sometag : someval')).to be_falsey
      expect(item.identityMetadata).to be_changed
    end
  end

  describe 'validate_and_normalize_tag' do
    it 'should throw an exception if tag has too few elements' do
      tag_str = 'just one part'
      expected_err_msg = "Invalid tag structure: tag '#{tag_str}' must have at least 2 elements"
      expect {item.validate_and_normalize_tag(tag_str, [])}.to raise_error(ArgumentError, expected_err_msg)
    end
    it 'should throw an exception if tag has empty elements' do
      tag_str = 'test part1 :  : test part3'
      expected_err_msg = "Invalid tag structure: tag '#{tag_str}' contains empty elements"
      expect {item.validate_and_normalize_tag(tag_str, [])}.to raise_error(ArgumentError, expected_err_msg)
    end
    it 'should throw an exception if tag is the same as an existing tag' do
      # note that tag_str should match existing_tags[1] because the comparison should happen after normalization, and it should
      # be case-insensitive.
      tag_str = 'another:multi:part:test'
      existing_tags = ['test part1 : test part2', 'Another : Multi : Part : Test', 'one : last_tag']
      expected_err_msg = "An existing tag (#{existing_tags[1]}) is the same, consider using update_tag?"
      expect {item.validate_and_normalize_tag(tag_str, existing_tags)}.to raise_error(StandardError, expected_err_msg)
    end
  end

  describe 'identity_metadata_source' do
    it 'should index metadata source' do
      expect(item.identity_metadata_source).to eq 'Symphony'
    end
  end

  describe 'to_solr' do
    it 'should generate collection and apo title fields' do
      allow(item.datastreams['RELS-EXT']).to receive(:content).and_return(@mock_rels_ext_xml)
      allow(Dor).to receive(:find).with(@mock_rel_druid).and_raise(ActiveFedora::ObjectNotFoundError)
      doc = item.to_solr

      ['apo_title', 'nonhydrus_apo_title'].each do |field_name|
        expect(doc[Solrizer.solr_name(field_name, :symbol)].first).to eq(@mock_rel_druid)
        expect(doc[Solrizer.solr_name(field_name, :stored_searchable)].first).to eq(@mock_rel_druid)
      end
    end
    it 'should index metadata source' do
      expect(item.to_solr).to match a_hash_including('metadata_source_ssi' => 'Symphony')
    end
    it 'should generate set collection and apo fields to the druid if the collection or apo does not exist' do
      allow(item.datastreams['RELS-EXT']).to receive(:content).and_return(@mock_rels_ext_xml)
      allow(Dor).to receive(:find).with(@mock_rel_druid).and_raise(ActiveFedora::ObjectNotFoundError)
      doc = item.to_solr

      ['apo_title', 'collection_title'].each do |field_name|
        expect(doc[Solrizer.solr_name(field_name, :symbol)].first).to eq(@mock_rel_druid)
        expect(doc[Solrizer.solr_name(field_name, :stored_searchable)].first).to eq(@mock_rel_druid)
      end
    end
  end

  describe 'get_related_obj_display_title' do
    it 'should return the descMetadata main title if it is available' do
      mock_apo_title = 'apo title'
      mock_apo_obj = double(Dor::AdminPolicyObject, full_title: mock_apo_title)

      mock_default_title = 'druid:zy098xw7654'
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_apo_title)
    end
    it 'should return the default if the first descMetadata main title entry is empty string' do
      mock_apo_obj = double(Dor::AdminPolicyObject, full_title: nil)

      mock_default_title = 'druid:zy098xw7654'
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_default_title)
    end
    it 'should return the default if the related object is nil' do
      mock_apo_obj = nil
      mock_default_title = 'druid:zy098xw7654'
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_default_title)
    end
  end

  describe '#adapt_to_cmodel' do
    context 'for a Hydrus collection' do
      let(:item) { instantiate_fixture('druid:kq696sh3014', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Collection
      end
    end

    context 'for a Hydrus item' do
      let(:item) { instantiate_fixture('druid:bb004bn8654', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Item
      end
    end

    context 'for a Dor item' do
      let(:item) { instantiate_fixture('druid:dc235vd9662', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Item
      end
    end

    context 'for an agreement' do
      let(:item) { instantiate_fixture('druid:dd327qr3670', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Agreement
      end
    end

    context 'for an object without identityMetadata or a RELS-EXT model' do
      let(:item) { item_from_foxml(read_fixture('foxml_empty.xml'), Dor::Abstract) }

      it 'defaults to Dor::Item' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Item
      end
    end
  end
end
