require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::Upgradable do
  
  before :each do
    module UpgradableTest
      class Foo
        include Dor::Upgradable
      end

      class Bar
        include Dor::Upgradable
      end

      class Baz < Bar
        def datastreams
          {}
        end
      end
      
      class Quux
      end
      
      def self.define_upgrades
        UpgradableTest::Foo.on_upgrade '1.0.1' do |obj|
          obj.signal(obj, 'foo_2')
        end
    
        UpgradableTest::Foo.on_upgrade '1.0.0' do |obj|
          obj.signal(obj, 'foo')
        end

        UpgradableTest::Bar.on_upgrade '1.0.0' do |obj|
          obj.signal(obj, 'bar')
        end

        UpgradableTest::Baz.on_upgrade '1.0.0' do |obj|
          obj.signal(obj, 'baz')
        end
      end
    end

    @foo = UpgradableTest::Foo.new
    @bar = UpgradableTest::Bar.new
    @baz = UpgradableTest::Baz.new
  end

  after :each do
    Object.instance_eval { remove_const :UpgradableTest }
  end
  
  it "should allow callbacks to be defined" do
    Dor::Upgradable.should_receive(:add_upgrade_callback).exactly(4).times
    UpgradableTest.define_upgrades
  end
  
  it "should send an upgrade to the relevant class" do
    UpgradableTest.define_upgrades
    @foo.should_receive(:save)
    @foo.should_receive(:signal).with(@foo,'foo').ordered
    @foo.should_receive(:signal).with(@foo,'foo_2').ordered

    @foo.upgrade!
  end
  
  it "should send an upgrade to descendant classes" do
    UpgradableTest.define_upgrades
    @baz.should_receive(:signal).with(@baz,'bar')
    @baz.should_receive(:signal).with(@baz,'baz')
    @baz.should_receive(:save)

    @baz.upgrade!
  end
  
  it "should send an upgrade to datastreams" do
    UpgradableTest.define_upgrades
    datastreams = { 'a' => UpgradableTest::Foo.new, 'b' => UpgradableTest::Bar.new, 'c' => UpgradableTest::Quux.new }

    @baz.stub(:datastreams).and_return(datastreams)
    @baz.should_receive(:signal).with(@baz,'bar')
    @baz.should_receive(:signal).with(@baz,'baz')
    @baz.should_receive(:save)

    datastreams.values.each { |v| v.should_receive(:new?).and_return(false) }
    datastreams['a'].should_receive(:signal).with(datastreams['a'],'foo')
    datastreams['a'].should_receive(:signal).with(datastreams['a'],'foo_2')
    datastreams['b'].should_receive(:signal).with(datastreams['b'],'bar')
    datastreams['c'].should_not_receive(:signal)

    @baz.upgrade!
  end
end
