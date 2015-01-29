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

  describe 'to_solr' do
    it 'should generate collection and apo title fields' do
      xml='<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
              <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
            </rdf:Description>
          </rdf:RDF>'
      allow(item.datastreams['RELS-EXT']).to receive(:content).and_return(xml)
      doc=item.to_solr
      #doc.keys.sort.each do |key|
      #  puts "#{key} #{doc[key]}"
      #end
      expect(doc[Solrizer.solr_name('apo_title', :facetable)].first).to eq('druid:fg890hi1234')
    end
  end
end

describe "Adding release tags", :vcr do
  before :each do

    Dor::Config.push! do
      cert_dir = File.expand_path('../../certs', __FILE__)
      ssl do
        #If rerecording or adding new cassettes, point these to real files
        cert_file File.join(cert_dir,"spec.crt")
        key_file File.join(cert_dir,"spec.key")
        key_pass ''
      end
      solrizer.url "http://127.0.0.1:8080/solr/argo_test"
      fedora.url "https://sul-dor-test.stanford.edu/fedora"

    end

    VCR.use_cassette('releaseable_sample_obj') do
      @item = Dor::Item.find('druid:bb004bn8654')
      @release_tags = @item.release_tags
    end
  end

  after :each do
    Dor::Config.pop!
  end

  it "should raise an error when no :who, :to, or :what is supplied" do
      expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => nil, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
      expect{@item.valid_release_attributes_and_tag(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>nil, :what => 'collection', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
      expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => nil, :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end

  it "should raise an error when :who, :to, :what are supplied but are not strings" do
    expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 1, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>true, :what => 'collection', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    expect{@item.valid_release_attributes_and_tag(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => ['i','am','an','array'], :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end

  it "should not raise an error when :what is self or collection" do
    expect(@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be_truthy
    expect(@item.valid_release_attributes_and_tag(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'collection', :tag => 'Project:Fitch:Batch2'})).to be_truthy
  end

  it "should raise an error when :what is a string but is not self or collection" do
    expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'foo', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end

  it "should add a tag when all attributes are properly provided" do
    VCR.use_cassette('simple_release_tag_add_success_test') do
       expect(@item.add_tag(true, :release, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be_a_kind_of(Nokogiri::XML::Element)
    end
  end

  it "should fail to add a tag when there is an attribute error" do
    VCR.use_cassette('simple_release_tag_add_failure_test') do
       expect{@item.add_tag(true, :release, {:who => nil, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
       expect{@item.add_tag(false, :release, {:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project'})}.to raise_error(ArgumentError)
       expect{@item.add_tag(1, :release, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    end
  end

  it "should raise an error when :when is not supplied as iso8601 for valid_release_attributes" do
     expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-1-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end

  it "should return true when valid_release_attributes is called with valid attributes and no tag attribute" do
    expect(@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self'})).to be_truthy
  end

  it "should return true when valid_release_attributes is called with valid attributes and tag attribute" do
    expect(@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be_truthy
  end

  it "should raise a Runtime Error when valid_release_attributes is called with valid attributes but an invalid tag attribute" do
    expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Batch2'})}.to raise_error(ArgumentError)
  end

  it "should raise a Runtime Error when valid_release_attributes is called with a tag content that is not a boolean" do
    expect{@item.valid_release_attributes_and_tag(1, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end

  it "should return no release tags for an item that doesn't have any" do
    VCR.use_cassette('releaseable_no_release_tags') do
      no_tags_item = Dor::Item.find('druid:qv648vd4392')
      expect(no_tags_item.release_tags).to eq({})
    end
  end

  it "should return the releases for an item that has release tags" do
    expect(@release_tags).to be_a_kind_of(Hash)
    expect(@release_tags).to eq({"Revs"=>[{"tag"=>"true", "what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}, {"tag"=>"true", "what"=>"self", "when"=>Time.parse('2015-01-06 23:33:54Z'), "who"=>"carrickr", "release"=>true}, {"tag"=>"Project : Fitch : Batch2", "what"=>"self", "when"=>Time.parse('2015-01-06 23:40:01Z'), "who"=>"carrickr", "release"=>false}]})
  end

  it "should return a hash created from a single release tag" do
    n = Nokogiri('<release to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    expect(@item.release_tag_node_to_hash(n)).to eq({:to=>"Revs", :attrs=>{"what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}})
    n = Nokogiri('<release tag="Project : Fitch: Batch1" to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    expect(@item.release_tag_node_to_hash(n)).to eq({:to=>"Revs", :attrs=>{"tag"=> "Project : Fitch: Batch1", "what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}})
  end



  #expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}

end
