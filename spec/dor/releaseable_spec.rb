require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
#
describe Dor::Releaseable, :vcr do
  before :each do
    VCR.use_cassette('fetch_bryar_transam') do
      @bryar_trans_am = Dor::Item.find('druid:bb004bn8654')
      @bryar_trans_am_admin_tags = @bryar_trans_am.tags
      @bryar_trans_am_release_tags = @bryar_trans_am.release_tags
      @array_of_times = [Time.parse('2015-01-06 23:33:47Z').iso8601, Time.parse('2015-01-07 23:33:47Z').iso8601, Time.parse('2015-01-08 23:33:47Z').iso8601, Time.parse('2015-01-09 23:33:47Z').iso8601]
    end
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
  
  describe 'handling tags on objects and determining release status' do
  end
  
  
  

end