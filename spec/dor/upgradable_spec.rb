require 'spec_helper'

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

  it 'should allow callbacks to be defined' do
    expect(Dor::Upgradable).to receive(:add_upgrade_callback).exactly(5).times
    UpgradableTest.define_upgrades
  end

  it 'should send an upgrade to the relevant class' do
    UpgradableTest.define_upgrades
    expect(@foo).to receive(:save)
    expect(@foo).to receive(:signal).with(@foo, 'foo').ordered
    expect(@foo).to receive(:signal).with(@foo, 'foo_2').ordered
    @foo.upgrade!
  end

  it 'should send an upgrade to descendant classes' do
    UpgradableTest.define_upgrades
    expect(@baz).to receive(:signal).with(@baz, 'bar')
    expect(@baz).to receive(:signal).with(@baz, 'baz')
    expect(@baz).to receive(:save)

    @baz.upgrade!
  end

  it 'should send an upgrade to datastreams' do
    UpgradableTest.define_upgrades
    datastreams = { 'a' => UpgradableTest::Foo.new, 'b' => UpgradableTest::Bar.new, 'c' => UpgradableTest::Quux.new }

    allow(@baz).to receive(:datastreams).and_return(datastreams)
    expect(@baz).to receive(:signal).with(@baz, 'bar')
    expect(@baz).to receive(:signal).with(@baz, 'baz')
    expect(@baz).to receive(:save)

    datastreams.values.each { |v| expect(v).to receive(:new?).and_return(false) }
    expect(datastreams['a']).to receive(:signal).with(datastreams['a'], 'foo')
    expect(datastreams['a']).to receive(:signal).with(datastreams['a'], 'foo_2')
    expect(datastreams['b']).to receive(:signal).with(datastreams['b'], 'bar')
    expect(datastreams['c']).not_to receive(:signal)

    @baz.upgrade!
  end

  it 'should send event notifications when an upgrade is done' do
    UpgradableTest.define_upgrades
    allow(@bar).to receive(:add_event)
    expect(@bar).to receive(:signal).with(@bar, 'bar')
    expect(@bar).to receive(:add_event).with('remediation', 'UpgradableTest::Bar 1.0.0', 'Signal bar')
    expect(@bar).not_to receive(:add_event).with('remediation', 'UpgradableTest::Bar 1.0.1', 'NEVER RUN')
    expect(@bar).to receive(:save)
    @bar.upgrade!
  end

  it 'should only save if upgrades were run' do
    UpgradableTest::Foo.on_upgrade '1.0.2', 'This should never run' do
      if false
        obj.signal('This will never run')
        true
      else
        false
      end
    end
    expect(@foo).not_to receive(:signal)
    expect(@foo).not_to receive(:save)
    @foo.upgrade!
  end
end
