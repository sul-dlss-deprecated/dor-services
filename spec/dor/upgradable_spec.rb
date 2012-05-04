require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::Upgradable do
  
  before :each do
    module UpgradableTest
      class Foo
        include Dor::Upgradable
        def pid; 'foo'; end
      end

      class Bar
        include Dor::Upgradable
        def pid; 'bar'; end
      end

      class Baz < Bar
        def datastreams
          {}
        end
        def pid; 'baz'; end
      end
      
      class Quux
        def pid; 'quux'; end
      end
      
      def self.define_upgrades
        UpgradableTest::Foo.on_upgrade '1.0.1', 'Signal foo 2' do |obj|
          obj.signal(obj, 'foo_2')
          true
        end
    
        UpgradableTest::Foo.on_upgrade '1.0.0', 'Signal foo 1' do |obj|
          obj.signal(obj, 'foo')
          true
        end

        UpgradableTest::Bar.on_upgrade '1.0.0', 'Signal bar' do |obj|
          obj.signal(obj, 'bar')
          true
        end
        
        UpgradableTest::Bar.on_upgrade '1.0.1', 'NEVER RUN'  do |obj|
          false
        end

        UpgradableTest::Baz.on_upgrade '1.0.0', 'Signal baz' do |obj|
          obj.signal(obj, 'baz')
          true
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
    Dor::Upgradable.should_receive(:add_upgrade_callback).exactly(5).times
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
  
  it "should send event notifications when an upgrade is done" do
    UpgradableTest.define_upgrades
    @bar.stub(:add_event)
    @bar.should_receive(:signal).with(@bar,'bar')
    @bar.should_receive(:add_event).with('remediation', "UpgradableTest::Bar 1.0.0", "Signal bar")
    @bar.should_not_receive(:add_event).with('remediation', "UpgradableTest::Bar 1.0.1", "NEVER RUN")
    @bar.should_receive(:save)
    @bar.upgrade!
  end
  
  it "should only save if upgrades were run" do
    UpgradableTest::Foo.on_upgrade '1.0.2', 'This should never run' do
      if false
        obj.signal('This will never run')
        true
      else
        false
      end
    end
    @foo.should_not_receive(:signal)
    @foo.should_not_receive(:save)
    @foo.upgrade!
  end
end
