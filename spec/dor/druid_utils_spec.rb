require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'dor/utils/druid_utils'

describe Druid do
  before (:all) do
    @fixture_dir = File.expand_path("../../fixtures",File.dirname(__FILE__))
    FileUtils.rm_rf(File.join(@fixture_dir,'cd'))
    @druid_1 = 'druid:cd456ef7890'
    @tree_1 = File.join(@fixture_dir,'cd/456/ef/7890')
    @druid_2 = 'druid:cd456gh1234'
    @tree_2 = File.join(@fixture_dir,'cd/456/gh/1234')
  end
  
  after(:each) do
    FileUtils.rm_rf(File.join(@fixture_dir,'cd'))
  end

  it "should extract the ID from the stem" do
    Druid.new('druid:cd456ef7890').id.should == 'cd456ef7890'
    Druid.new('cd456ef7890').id.should == 'cd456ef7890'
  end

  it "should raise an exception if the druid is invalid" do
    lambda { Druid.new('nondruid:cd456ef7890') }.should raise_error(ArgumentError)
    lambda { Druid.new('druid:cd4567ef890') }.should raise_error(ArgumentError)
  end
  
  it "should build a druid tree from a druid" do
    druid = Druid.new(@druid_1)
    druid.tree.should == ['cd','456','ef','7890']
    druid.path(@fixture_dir).should == @tree_1
  end
  
  it "should create and destroy druid directories" do
    File.exists?(@tree_1).should be_false
    File.exists?(@tree_2).should be_false

    druid_1 = Druid.new(@druid_1)
    druid_2 = Druid.new(@druid_2)

    druid_1.mkdir(@fixture_dir)
    File.exists?(@tree_1).should be_true
    File.exists?(@tree_2).should be_false

    druid_2.mkdir(@fixture_dir)
    File.exists?(@tree_1).should be_true
    File.exists?(@tree_2).should be_true
    
    druid_2.rmdir(@fixture_dir)
    File.exists?(@tree_1).should be_true
    File.exists?(@tree_2).should be_false

    druid_1.rmdir(@fixture_dir)
    File.exists?(@tree_1).should be_false
    File.exists?(@tree_2).should be_false
    File.exists?(File.join(@fixture_dir,'cd')).should be_false
  end
  
  describe "#mkdir error handling" do
    it "raises SameContentExistsError if the directory already exists" do
      druid_2 = Druid.new(@druid_2)
      druid_2.mkdir(@fixture_dir)
      lambda { druid_2.mkdir(@fixture_dir) }.should raise_error(Dor::SameContentExistsError)
    end
    
    it "raises DifferentContentExistsError if a link already exists in the workspace for this druid" do
      source_dir = '/tmp/content_dir'
      FileUtils.mkdir_p(source_dir)      
      dr = Druid.new(@druid_2)
      dr.mkdir_with_final_link(source_dir, @fixture_dir)
      lambda { dr.mkdir(@fixture_dir) }.should raise_error(Dor::DifferentContentExistsError)
    end
  end
  
  describe "#mkdir_with_final_link" do
    
    before(:each) do
      @source_dir = '/tmp/content_dir'
      FileUtils.mkdir_p(@source_dir)      
      @dr = Druid.new(@druid_2)
    end
    
    it "creates a druid tree in the workspace with the final directory being a link to the passed in source" do
      @dr.mkdir_with_final_link(@source_dir, @fixture_dir)

      File.should be_symlink(@dr.path(@fixture_dir))
      File.readlink(@tree_2).should == @source_dir
    end
    
    it "raises SameContentExistsError if the link to source already exists" do
      @dr.mkdir_with_final_link(@source_dir, @fixture_dir)
      lambda { @dr.mkdir_with_final_link(@source_dir, @fixture_dir) }.should raise_error(Dor::SameContentExistsError)
    end
    
    it "raises DifferentContentExistsError if a directory already exists in the workspace for this druid" do
      @dr.mkdir(@fixture_dir)
      lambda { @dr.mkdir_with_final_link(@source_dir, @fixture_dir) }.should raise_error(Dor::DifferentContentExistsError)
    end
  end
  
end
