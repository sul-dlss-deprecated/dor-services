require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'dor-services'

describe Dor do
  
  it "should reload all modules" do
    old_config = Dor::Config.to_hash
    Dor.reload!.should == Dor
    Dor::Config.to_hash.should == old_config
  end

end