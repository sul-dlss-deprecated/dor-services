require 'spec_helper'

class IdentifiableItem < ActiveFedora::Base
  include Dor::Identifiable
end

describe Dor::Identifiable do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  let(:item) do
    item = instantiate_fixture('druid:ab123cd4567', IdentifiableItem)
    allow(item).to receive(:new?).and_return(false)
    ds = item.identityMetadata
    ds.instance_variable_set(:@datastream_content, item.identityMetadata.content)
    allow(ds).to receive(:new?).and_return(false)
    item
  end

  it "should have an identityMetadata datastream" do
    expect(item.datastreams['identityMetadata']).to be_a(Dor::IdentityMetadataDS)
  end
  describe 'set_source_id' do
    it 'should set the source_id if one doesnt exist' do
      expect(item.identityMetadata.sourceId).to eq('google:STANFORD_342837261527')
      item.set_source_id('fake:sourceid')
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
    end
    it 'should replace the source_id if one exists' do
      item.set_source_id('fake:sourceid')
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
      item.set_source_id('new:sourceid2')
      expect(item.identityMetadata.sourceId).to eq('new:sourceid2')
    end
  end

  describe 'add_other_Id' do
    it 'should add an other_id record' do
      item.add_other_Id('mdtoolkit','someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
    end
    it 'should raise an exception if a record of that type already exists' do
      item.add_other_Id('mdtoolkit','someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      expect{item.add_other_Id('mdtoolkit','someid123')}.to raise_error
    end
  end

  describe 'update_other_Id' do
    it 'should update an existing id and return true to indicate that it found something to update' do
      item.add_other_Id('mdtoolkit','someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      #return value should be true when it finds something to update
      expect(item.update_other_Id('mdtoolkit','someotherid234','someid123')).to be_truthy
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someotherid234')
    end
    it 'should return false if there was no existing record to update' do
      expect(item.update_other_Id('mdtoolkit','someotherid234')).to be_falsey
    end
  end

  describe 'remove_other_Id' do
    it 'should remove an existing otherid when the tag and value match' do
      item.add_other_Id('mdtoolkit','someid123')
      expect(item.identityMetadata.otherId('mdtoolkit').first).to eq('someid123')
      expect(item.remove_other_Id('mdtoolkit','someid123')).to be_truthy
      expect(item.identityMetadata.otherId('mdtoolkit').length).to eq(0)
    end
    it 'should return false if there was nothing to delete' do
      expect(item.remove_other_Id('mdtoolkit','someid123')).to be_falsey
      expect(item.identityMetadata).not_to be_changed
    end
    it 'should affect identity_metadata_source computation' do
      item.remove_other_Id('catkey','129483625')
      item.remove_other_Id('barcode','36105049267078')
      item.add_other_Id('mdtoolkit','someid123')
      expect(item.identity_metadata_source).to eq 'Metadata Toolkit'
      item.add_other_Id('catkey','129483625')
      item.remove_other_Id('mdtoolkit','someid123')
      expect(item.identity_metadata_source).to eq 'Symphony'
      item.remove_other_Id('catkey','129483625')
      item.add_other_Id('barcode','36105049267078')
      expect(item.identity_metadata_source).to eq 'Symphony'
      item.remove_other_Id('barcode','36105049267078')
      expect(item.identity_metadata_source).to eq 'DOR'
      item.remove_other_Id('foo','bar')
      expect(item.identity_metadata_source).to eq 'DOR'
    end
  end

  # when looking for tags after addition/update/removal, check for the normalized form.
  # when doing the add/update/removal, specify the tag in non-normalized form so that the
  # normalization mechanism actually gets tested.
  describe 'add_tag' do
    it 'should add a new tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end
    it 'should raise an exception if there is an existing tag like it' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_truthy
      expect {item.add_tag('sometag: someval')}.to raise_error
    end
  end

  describe 'update_tag' do
    it 'should update a tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_truthy
      expect(item.update_tag('sometag :someval','new :tag')).to be_truthy
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_falsey
      expect(item.identityMetadata.tags().include?('new : tag')).to be_truthy
      expect(item.identityMetadata).to be_changed
    end
    it 'should return false if there is no matching tag to update' do
      expect(item.update_tag('sometag:someval','new:tag')).to be_falsey
      expect(item.identityMetadata).not_to be_changed
    end
  end

  describe 'remove_tag' do
    it 'should delete a tag' do
      item.add_tag('sometag:someval')
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_truthy
      expect(item.remove_tag('sometag:someval')).to be_truthy
      expect(item.identityMetadata.tags().include?('sometag : someval')).to be_falsey
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
      mock_apo_druid = 'druid:fg890hi1234'
      mock_rels_ext_xml = %{<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
              <hydra:isGovernedBy rdf:resource="info:fedora/#{mock_apo_druid}"/>
            </rdf:Description>
          </rdf:RDF>}

      allow(item.datastreams['RELS-EXT']).to receive(:content).and_return(mock_rels_ext_xml)
      allow(Dor).to receive(:find).with(mock_apo_druid).and_return(nil)

      doc = item.to_solr

      expect(doc[Solrizer.solr_name('apo_title', :symbol)].first).to eq(mock_apo_druid)
      expect(doc[Solrizer.solr_name('apo_title', :stored_searchable)].first).to eq(mock_apo_druid)
    end
    it 'should index metadata source' do
      expect(item.to_solr).to match a_hash_including('metadata_source_ssi' => 'Symphony')
    end
  end
  describe 'get_related_obj_display_title' do
    it 'should return the dc:title if it is available' do
      mock_apo_title = "apo title"
      mock_apo_obj = double(Dor::AdminPolicyObject)
      mock_dc_datastream = double(Dor::SimpleDublinCoreDs)

      allow(mock_dc_datastream).to receive(:title).and_return(mock_apo_title)
      allow(mock_apo_obj).to receive(:datastreams).and_return({"DC" => mock_dc_datastream})

      mock_default_title = "druid:zy098xw7654"
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_apo_title)
    end
    it 'should return the fedora label if the dc:title is not available' do
      mock_apo_label = "object label"
      mock_apo_obj = double(Dor::AdminPolicyObject)

      allow(mock_apo_obj).to receive(:label).and_return(mock_apo_label)
      allow(mock_apo_obj).to receive(:datastreams).and_return({})

      mock_default_title = "druid:zy098xw7654"
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_apo_label)
    end
    it 'should return the default if the related object is nil' do
      mock_apo_obj = nil
      mock_default_title = "druid:zy098xw7654"
      expect(item.get_related_obj_display_title(mock_apo_obj, mock_default_title)).to eq(mock_default_title)
    end
  end
end
