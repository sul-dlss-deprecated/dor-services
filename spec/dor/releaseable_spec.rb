require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
#
describe Dor::Releaseable, :vcr do
  before :each do
    
    Dor::Config.push! do
      solrizer.url "http://127.0.0.1:8080/solr/argo_test"
      fedora.url "https://sul-dor-test.stanford.edu/fedora"
      stacks.document_cache_host "purl-test.stanford.edu"
    end
    
    VCR.use_cassette('fetch_bryar_transam') do
      @bryar_trans_am_druid = 'druid:bb004bn8654'
      @bryar_trans_am = Dor::Item.find(@bryar_trans_am_druid)
      @bryar_trans_am_admin_tags = @bryar_trans_am.tags
      @bryar_trans_am_release_tags = @bryar_trans_am.release_nodes
      @array_of_times = [Time.parse('2015-01-06 23:33:47Z').iso8601, Time.parse('2015-01-07 23:33:47Z').iso8601, Time.parse('2015-01-08 23:33:47Z').iso8601, Time.parse('2015-01-09 23:33:47Z').iso8601]
    end
    
  end
  
  after :each do
    Dor::Config.pop!
  end
  
  describe "Tag sorting, combining, and comparision functions" do
    
    before :each do
      @dummy_tags = [{'when' => @array_of_times[0], 'tag' => "Project: Jim Harbaugh's Finest Moments At Stanford.", "what" => "self"}, {'when' => @array_of_times[1], 'tag' => "Project: Jim Harbaugh's Even Finer Moments At Michigan.", "what" => "collection"}]
    end
    
    it 'should return the most recent tag from an array of release tags' do
      expect(@bryar_trans_am.newest_release_tag_in_an_array(@dummy_tags)).to eq(@dummy_tags[1])
    end
        
    it 'should return nil when no tags apply' do
      expect(@bryar_trans_am.latest_applicable_release_tag_in_array(@dummy_tags, @bryar_trans_am_admin_tags)).to be_nil
    end
    
    it 'should return a tag when it does apply' do
      valid_tag = {'when' => @array_of_times[3], 'tag' => 'Project : Revs'}
      expect(@bryar_trans_am.latest_applicable_release_tag_in_array(@dummy_tags << valid_tag, @bryar_trans_am_admin_tags)).to eq(valid_tag)
    end
    
    it 'should return a valid tag even if there are non applicable older ones in front of it' do
      valid_tag = {'when' => @array_of_times[2], 'tag' => 'Project : Revs'}
      newer_no_op_tag = {'when' => @array_of_times[3], 'tag' => "Jim Harbaugh's Nonexistent Moments With The Raiders"}
      expect(@bryar_trans_am.latest_applicable_release_tag_in_array(@dummy_tags + [valid_tag, newer_no_op_tag], @bryar_trans_am_admin_tags)).to eq(valid_tag)
    end
    
    it 'should return the most recent tag when there are two valid tags' do
      valid_tag = {'when' => @array_of_times[2], 'tag' => 'Project : Revs'}
      newer_valid_tag = {'when' => @array_of_times[3], 'tag' => 'tag : test1'}
      expect(@bryar_trans_am.latest_applicable_release_tag_in_array(@dummy_tags + [valid_tag, newer_valid_tag], @bryar_trans_am_admin_tags)).to eq(newer_valid_tag)
    end
    
    it 'should recongize at a release tag with no tag attribute applies' do
      local_dummy_tag = {'when' =>  @array_of_times[0], 'who' => 'carrickr' }
      expect(@bryar_trans_am.does_release_tag_apply(local_dummy_tag, @bryar_trans_am_admin_tags)).to eq(true)
    end
    
    it 'should not require admin tags to be passed in' do
      local_dummy_tag = {'when' =>  @array_of_times[0], 'who' => 'carrickr' }
      expect(@bryar_trans_am.does_release_tag_apply(local_dummy_tag)).to eq(true)
      expect(@bryar_trans_am.does_release_tag_apply(@dummy_tags[0])).to eq(false)
    end
    
    it 'should only return the request attribute(s) for purl' do
      dummy_tag = @dummy_tags[0]
      dummy_tag['release'] = false
      expect(@bryar_trans_am.clean_release_tag_for_purl(dummy_tag)).to eq({'release' => false})
    end
    
    it 'should return the latest tag for each key/target in a hash' do
      dummy_hash = {'Revs' =>  @dummy_tags, 'FRDA' =>  @dummy_tags}
      expect(@bryar_trans_am.get_newest_release_tag(dummy_hash)).to eq({"Revs" => @dummy_tags[1], 'FRDA' => @dummy_tags[1]})
    end
    
    it 'should only return tags for the specific what value' do
      expect(@bryar_trans_am.get_tags_for_what_value({'Revs' => @dummy_tags}, 'self')).to eq({'Revs' => [@dummy_tags[0]]})
      expect(@bryar_trans_am.get_tags_for_what_value({'Revs' => @dummy_tags, 'FRDA' => @dummy_tags}, 'collection')).to eq({'Revs' => [@dummy_tags[1]], 'FRDA' => [@dummy_tags[1]]})
    end
    
    it 'should combine two hashes of tags without overwriting any data' do
      h_one = {'Revs' => [@dummy_tags[0]]}
      h_two = {'Revs' => [@dummy_tags[1]], 'FRDA' => @dummy_tags}
      expected_result = {'Revs' => @dummy_tags, 'FRDA' => @dummy_tags}
      expect(@bryar_trans_am.combine_two_release_tag_hashes(h_one, h_two)).to eq(expected_result)
    end
    
    it 'should only return self release tags' do
      expect(@bryar_trans_am.get_self_release_tags({'Revs' => @dummy_tags, 'FRDA' => @dummy_tags, 'BV' => [@dummy_tags[1]]})).to eq({'Revs' => [@dummy_tags[0]], 'FRDA' => [@dummy_tags[0]]})
    end
    
  end
  
  #Warning:  Exercise care when rerecording these cassette, as these items are set up to have specific tags on them at the time of recording, other folks messing around in the dev environment might add or remove release tags that cause failures on these tests
  #If these tests fail, check not just the logic, but also the specific tags
  describe 'handling tags on objects and determining release status' do
    
      it "should use only the most recent self tag to determine if an item is released, with no release tags on the collection" do
        VCR.use_cassette('releaseable_self_tags_only') do
          item = Dor::Item.find('druid:vs298kg2555')
          expect(item.released_for['Kurita']['release']).to eq(true)
        end
      end
      
      #This test takes an object with a self tag that is older and opposite the tag on this object's collection and ensures the self tag still is the one that is used to decide release status
      it "should use the self tag over the collection tag to determine if an item is released, even if the collection tag is newer" do
        VCR.use_cassette('releaseable_self_over_collection') do
          item = Dor::Item.find('druid:bb537hc4022')
          expect(item.released_for['Kurita']['release']).to eq(false)
        end
      end
      
      #This test looks at an item whose only tags are on the collection and ensures the most recent one wins
      it "should use only most the recent collection tag if no self tags are present" do
        VCR.use_cassette('releaseable_most_recent_collection_tag_wins') do
          item = Dor::Item.find('druid:bc566xq6031')
          expect(item.release_tags).to eq({})
          expect(item.released_for['Kurita']['release']).to eq(true)
        end
      end
      
      #A collection whose only tag is to release a what=collection should also release the collection object itself
      it "a tag with what=collection should release the collection item, assuming it is not blocked by a self tag" do
        VCR.use_cassette('releaseable_collection_tag_releases_collection_object') do
          item = Dor::Item.find('druid:wz243gf4151')
          expect(item.released_for['Kurita']['release']).to eq(true)
        end
      end
      
      #Here we have an object governed by both the Marcus Chambers, druid:wz243gf4151, Collection and the Revs Collection, druid:nt028fd5773
      #When determining if an item is released, it should look at both collections and pick the most recent timestamp
      it "should look all collections and sets that an item is a member of" do
        VCR.use_cassette('releaseable_multiple_collections') do
          item = Dor::Item.find('druid:dc235vd9662')
          expect(item.released_for['Atago']['release']).to eq(false)
          chambers_collection = Dor::Item.find('druid:wz243gf4151')
          expect(chambers_collection.release_tags["Atago"]).to eq ([{"what"=>"collection", "who"=>"carrickr", "when"=>Time.parse('2015-01-21 22:37:21Z').iso8601, "release"=>true}])
          revs_collection = Dor::Item.find('druid:nt028fd5773')
          expect(revs_collection.release_tags['Atago']).to eq([{"what"=>"collection", "who"=>"carrickr", "when"=>Time.parse('2015-01-21 22:37:40Z').iso8601, "release"=>false}])
        end 
      end
      
      #If an items release is controlled with the tag= attr, meaning that only items with that administrative tag are released, that should be respected
      it "should respect the tag= attr and apply it when releasing" do
        VCR.use_cassette('releaseable_respect_admin_tagging') do
          chambers_collection = Dor::Item.find('druid:wz243gf4151')
          expect(chambers_collection.release_tags['Mogami']).to eq( [{"what"=>"collection", "who"=>"carrickr", "tag"=>"Project : ReleaseSpecTesting : Batch1", "when"=>Time.parse('2015-01-21 22:46:22Z').iso8601, "release"=>true}]) 
          item_with_this_admin_tag = Dor::Item.find('druid:dc235vd9662')
          expect(item_with_this_admin_tag.tags.include?('Project : ReleaseSpecTesting : Batch1')).to eq(true)
          expect(item_with_this_admin_tag.released_for['Mogami']['release']).to eq(true)
          item_without_this_admin_tag = item = Dor::Item.find('druid:bc566xq6031')
          expect(item_without_this_admin_tag.tags.include?('Project : ReleaseSpecTesting : Batch1')).to eq(false)
          expect(item_without_this_admin_tag.released_for['Mogami']).to eq(nil)
        end
      end
      
      #If an item has no release tags on it for a target it should just return nil when queried with regard to that target
      it "should return nil if no tags exist on an item with regard to that target" do
          VCR.use_cassette('releaseable_nil_target') do
            item = Dor::Item.find('druid:bc566xq6031')
            expect(item.released_for['Runner II']).to eq(nil)
          end
      end
      
      it 'should return release xml for an item as string of elements wrapped in a ReleaseDigestRoot' do
        VCR.use_cassette('releaseable_release_xml') do
          item = Dor::Item.find('druid:dc235vd9662')
          release_xml = item.generate_release_xml
          expect(release_xml.class).to eq(String)
          true_or_false = ['true', 'false']
          xml_obj = Nokogiri(release_xml)
          xml_obj.xpath('//release').each do |release_node|
            expect(release_node.name).to eq('release')  #Well, duh
            expect(release_node.attributes.keys).to eq(['to'])
            expect(release_node.attributes.keys).to eq(['to'])
            expect(release_node.attributes['to'].value.class).to eq(String)
            expect(true_or_false.include? release_node.children.text).to eq(true)
          end
        end
      end
      

      
    
  end

end

describe "Adding release nodes", :vcr do
  before :each do
    
    Dor::Config.push! do
      cert_dir = File.expand_path('../../certs', __FILE__)
      ssl do
        #If rerecording or adding new cassettes, point these to real files
        cert_file File.join(cert_dir,"robots-dor-test.crt")
        key_file File.join(cert_dir,"robots-dor-test.key")
        key_pass ''
      end
      solrizer.url "http://127.0.0.1:8080/solr/argo_test"
      fedora.url "https://sul-dor-test.stanford.edu/fedora"
      stacks.document_cache_host "purl-test.stanford.edu"
      
    end
    
    VCR.use_cassette('releaseable_sample_obj') do
      @item = Dor::Item.find('druid:bb004bn8654')
      @release_nodes = @item.release_nodes
      @le_mans_druid = 'druid:dc235vd9662'
    end
  end
  
  after :each do
    Dor::Config.pop!
  end
  
  it "should raise an error when no :who, :to,  or :what is supplied" do
      expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => nil, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
      expect{@item.valid_release_attributes(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>nil, :what => 'collection', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
      expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => nil, :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end
  
  it "should raise an error when :who, :to, :what are supplied but are not strings" do 
    expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 1, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>true, :what => 'collection', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    expect{@item.valid_release_attributes(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => ['i','am','an','array'], :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end
  
  it "should not raise an error when :what is self or collection" do 
    expect(@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be true 
    expect(@item.valid_release_attributes(false, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'collection', :tag => 'Project:Fitch:Batch2'})).to be true 
  end
  
  it "should raise an error when :what is a string but is not self or collection" do
    expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'foo', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end 
  
  it "should add a tag when all attributes are properly provided" do
    VCR.use_cassette('simple_release_tag_add_success_test') do
       expect(@item.add_release_node(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be_a_kind_of(Nokogiri::XML::Element)
    end
  end
  
  it "should fail to add a release node when there is an attribute error" do
    VCR.use_cassette('simple_release_tag_add_failure_test') do
       expect{@item.add_release_node(true, {:who => nil, :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
       expect{@item.add_release_node(false, {:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project'})}.to raise_error(RuntimeError)
       expect{@item.add_release_node(1, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
    end
  end
  
  it "should raise an error when :when is not supplied as iso8601 for valid_release_attributes" do
     expect{@item.valid_release_attributes(true, {:when=>'2015-1-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end
  
  it "should return true when valid_release_attributes is called with valid attributes and no tag attribute" do
    expect(@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self'})).to be true 
  end
  
  it "should return true when valid_release_attributes is called with valid attributes and tag attribute" do
    expect(@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})).to be true 
  end
  
  it "should raise a Runtime Error when valid_release_attributes is called with valid attributes but an invalid tag attribute" do
    expect{@item.valid_release_attributes(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Batch2'})}.to raise_error(RuntimeError)
  end
  
  it "should raise a Runtime Error when valid_release_attributes is called with a tag content that is not a boolean" do
    expect{@item.valid_release_attributes(1, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}.to raise_error(ArgumentError)
  end
  
  it "should return no release nodes for an item that doesn't have any" do
    VCR.use_cassette('releaseable_no_release_tags') do
      no_release_nodes_item = Dor::Item.find('druid:qv648vd4392')
      expect(no_release_nodes_item.release_nodes).to eq({})
    end
  end
  
  it "should return the releases for an item that has release tags" do
    expect(@release_nodes).to be_a_kind_of(Hash)
    expect(@release_nodes).to eq({"Revs"=>[{"tag"=>"true", "what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}, {"tag"=>"true", "what"=>"self", "when"=>Time.parse('2015-01-06 23:33:54Z'), "who"=>"carrickr", "release"=>true}, {"tag"=>"Project : Fitch : Batch2", "what"=>"self", "when"=>Time.parse('2015-01-06 23:40:01Z'), "who"=>"carrickr", "release"=>false}]})
  end
  
  it "should return a hash created from a single release tag" do
    n = Nokogiri('<release to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    expect(@item.release_tag_node_to_hash(n)).to eq({:to=>"Revs", :attrs=>{"what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}}) 
    n = Nokogiri('<release tag="Project : Fitch: Batch1" to="Revs" what="collection" when="2015-01-06T23:33:47Z" who="carrickr">true</release>').xpath('//release')[0]
    expect(@item.release_tag_node_to_hash(n)).to eq({:to=>"Revs", :attrs=>{"tag"=> "Project : Fitch: Batch1", "what"=>"collection", "when"=>Time.parse('2015-01-06 23:33:47Z'), "who"=>"carrickr", "release"=>true}}) 
  end
  
  describe 'Getting XML From Purl' do 
    it 'should remove the druid prefix if it is present' do
      expect(@item.remove_druid_prefix).to eq('bb004bn8654')
    end
    
    it 'should return the full url for a druid' do
      expect(@item.form_purl_url).to eq("http://#{Dor::Config.stacks.document_cache_host}/bb004bn8654.xml")
    end
    
    
    it 'should get the purl xml for a druid' do
      VCR.use_cassette('fetch_purl_test_xml') do
        x = @item.get_xml_from_purl
        expect(x.class).to eq(Nokogiri::HTML::Document)
        expect(x.at_xpath("//html/body/publicobject").attr("id")).to eq(@item.id)
      end
    end
    
    it 'should not raise an error for a 404 when attempted to obtain a purl' do
      VCR.use_cassette('purl_404') do
        #expect(Time).to receive(:now).and_return(@now).at_least(:once)
        expect(@item).to receive(:id).and_return("druid:IAmABadDruid").at_least(:once)
        expect(@item.get_xml_from_purl.class).to eq(Nokogiri::HTML::Document)
      end
    end
    
    #TODO:  These two are pending because first we need to create and object in purl with a release data section, then we can record a purl fetch for them
    xit 'should get a list of release tags in druid for a druid' do
      VCR.use_cassette('fetch_le_mans_purl') do
        item = Dor::Item.find(@le_mans_druid)
        x = item.get_xml_from_purl
        expect(item.get_release_tags_from_purl_xml(x)).to match_array(['Kurita', 'Mogami','Atago'])
      end
    end
    
    xit 'should add in release tags as false for targets that are listed on the purl but not in new tag generation' do
      VCR.use_cassette('fetch_le_mans_purl') do
        item = Dor::Item.find(@le_mans_druid)
        x = item.get_xml_from_purl
        expect(item.add_tags_from_purl({})).to match({"Kurita"=>false, "Atago"=>false, "Mogami"=>false})
      end
    end
    
  end
  
  
  

  
  #expect{@item.valid_release_attributes_and_tag(true, {:when=>'2015-01-05T23:23:45Z',:who => 'carrickr', :to =>'Revs', :what => 'self', :tag => 'Project:Fitch:Batch2'})}
    
end
