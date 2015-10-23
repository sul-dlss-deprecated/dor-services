require 'spec_helper'

describe Dor::VersionTag do

  describe ".parse" do
    it "parses a String into a VersionTag object" do
      t = Dor::VersionTag.parse('1.1.0')
      t.major.should == 1
      t.minor.should == 1
      t.admin.should == 0
    end
  end

  describe "#increment" do
    let(:tag) { Dor::VersionTag.parse('1.2.3')  }

    it "adds 1 to major and zeros out minor and admin when :major is passed in" do
      tag.increment(:major)
      tag.major.should == 2
      tag.minor.should == 0
      tag.admin.should == 0
    end

    it "adds 1 to minor and zeros out admin when :minor is passed in" do
      tag.increment(:minor)
      tag.minor.should == 3
      tag.admin.should == 0
    end

    it "adds 1 to admin when :admin is passed in" do
      tag.increment(:admin)
      tag.admin.should == 4
    end
  end

  describe "ordering" do
    it "handles <, >, == comparisons" do
      v1 = Dor::VersionTag.new(1, 1, 0)
      v2 = Dor::VersionTag.new(1, 1, 2)
      v1.should < v2

      v3 = Dor::VersionTag.new(0, 1, 1)
      v1.should > v3

      v4 = Dor::VersionTag.new(1, 1, 0)
      v1.should == v4
    end
  end

end
