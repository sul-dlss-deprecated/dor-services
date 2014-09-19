require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class IdentifiableItem < ActiveFedora::Base
  include Dor::Identifiable
end

describe Dor::Identifiable do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  let(:item) do
    item = instantiate_fixture('druid:ab123cd4567', IdentifiableItem)
    item.stub(:new?).and_return(false)
    ds = item.identityMetadata
    ds.instance_variable_set(:@datastream_content, item.identityMetadata.content)
    ds.stub(:new?).and_return(false)
    item
  end

  it "should have an identityMetadata datastream" do
    item.datastreams['identityMetadata'].should be_a(Dor::IdentityMetadataDS)
  end
  describe 'set_source_id' do
    it 'should set the source_id if one doesnt exist' do
      item.identityMetadata.sourceId.should == 'google:STANFORD_342837261527'
      item.set_source_id('fake:sourceid')
      item.identityMetadata.sourceId.should == 'fake:sourceid'
    end
    it 'should replace the source_id if one exists' do
      item.set_source_id('fake:sourceid')
      item.identityMetadata.sourceId.should == 'fake:sourceid'
      item.set_source_id('new:sourceid2')
      item.identityMetadata.sourceId.should == 'new:sourceid2'
    end
  end

  describe 'add_other_Id' do
    it 'should add an other_id record' do
      item.add_other_Id('mdtoolkit','someid123')
      item.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
    end
    it 'should raise an exception if a record of that type already exists' do
      item.add_other_Id('mdtoolkit','someid123')
      item.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      lambda{item.add_other_Id('mdtoolkit','someid123')}.should raise_error
    end
  end

  describe 'update_other_Id' do
    it 'should update an existing id and return true to indicate that it found something to update' do
      item.add_other_Id('mdtoolkit','someid123')
      item.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      #return value should be true when it finds something to update
      item.update_other_Id('mdtoolkit','someotherid234','someid123').should == true
      item.identityMetadata.otherId('mdtoolkit').first.should == 'someotherid234'
    end
    it 'should return false if there was no existing record to update' do
      item.update_other_Id('mdtoolkit','someotherid234').should == false
    end
  end

  describe 'remove_other_Id' do
    it 'should remove an existing otherid when the tag and value match' do
      item.add_other_Id('mdtoolkit','someid123')
      item.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      item.remove_other_Id('mdtoolkit','someid123').should == true
      item.identityMetadata.otherId('mdtoolkit').length.should == 0
    end
    it 'should return false if there was nothing to delete' do
      item.remove_other_Id('mdtoolkit','someid123').should == false
      item.identityMetadata.should_not be_changed
    end
  end

  # when looking for tags after addition/update/removal, check for the normalized form.
  # when doing the add/update/removal, specify the tag in non-normalized form so that the
  # normalization mechanism actually gets tested.
  describe 'add_tag' do
    it 'should add a new tag' do
      item.add_tag('sometag:someval')
      item.identityMetadata.tags().include?('sometag : someval').should == true
      item.identityMetadata.should be_changed
    end
    it 'should raise an exception if there is an existing tag like it' do
      item.add_tag('sometag:someval')
      item.identityMetadata.tags().include?('sometag : someval').should == true
      lambda {item.add_tag('sometag: someval')}.should raise_error
    end
  end

  describe 'update_tag' do
    it 'should update a tag' do
      item.add_tag('sometag:someval')
      item.identityMetadata.tags().include?('sometag : someval').should == true
      item.update_tag('sometag :someval','new :tag').should == true
      item.identityMetadata.tags().include?('sometag : someval').should == false
      item.identityMetadata.tags().include?('new : tag').should == true
      item.identityMetadata.should be_changed
    end
    it 'should return false if there is no matching tag to update' do
      item.update_tag('sometag:someval','new:tag').should == false
      item.identityMetadata.should_not be_changed
    end
  end

  describe 'remove_tag' do
    it 'should delete a tag' do
    item.add_tag('sometag:someval')
    item.identityMetadata.tags().include?('sometag : someval').should == true
    item.remove_tag('sometag:someval').should == true
    item.identityMetadata.tags().include?('sometag : someval').should == false
      item.identityMetadata.should be_changed
    end
  end

  describe 'validate_and_normalize_tag' do
    it 'should throw an exception if tag has too few elements' do
      tag_str = 'just one part'
      expected_err_msg = "Invalid tag structure:  tag '#{tag_str}' must have at least 2 elements"
      lambda {item.validate_and_normalize_tag(tag_str, [])}.should raise_error(StandardError, expected_err_msg)
    end
    it 'should throw an exception if tag has empty elements' do
      tag_str = 'test part1 :  : test part3'
      expected_err_msg = "Invalid tag structure:  tag '#{tag_str}' contains empty elements"
      lambda {item.validate_and_normalize_tag(tag_str, [])}.should raise_error(StandardError, expected_err_msg)
    end
    it 'should throw an exception if tag is the same as an existing tag' do
      # note that tag_str should match existing_tags[1] because the comparison should happen after normalization
      tag_str = 'another:multi:part:test'
      existing_tags = ['test part1 : test part2', 'another : multi : part : test', 'one : last_tag']
      expected_err_msg = "An existing tag (#{existing_tags[1]}) is the same, consider using update_tag?"
      lambda {item.validate_and_normalize_tag(tag_str, existing_tags)}.should raise_error(StandardError, expected_err_msg)
    end
  end

  describe 'to_solr' do
    it 'should generate collection and apo title fields' do
      xml='<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
              <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
            </rdf:Description>
          </rdf:RDF>'
      item.datastreams['RELS-EXT'].stub(:content).and_return(xml)
      doc=item.to_solr
      #doc.keys.sort.each do |key|
      #  puts "#{key} #{doc[key]}"
      #end
      doc['apo_title_facet'].first.should == 'druid:fg890hi1234'
    end
  end
end
