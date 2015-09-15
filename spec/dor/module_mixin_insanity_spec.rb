require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'

module A
  extend ::ActiveSupport::Concern
  # included do puts "INCLUDING A" end
  def foobar(val = '')
    (begin super(val) rescue val end) + 'A'
  end
end

module B
  extend ::ActiveSupport::Concern
  include A
  # included do puts "INCLUDING B" end
  def foobar(val = '')
    super + 'B'
  end
end

class TypeA
  include A
end
class TypeB
  include B
end
class TypeAB
  include A
  include B   # already implies A
end
class TypeBA
  include B   # already implies A
  include A
  def foobar(val = '')
    super + 'X'
  end
end
class TypeC < TypeBA
  include A   # already included by parent
  def foobar(val = '')
    super + 'Y'
  end
end

describe 'Module Mixin' do
  before(:each) do
    @a = TypeA.new
    @b = TypeB.new
    @ab = TypeAB.new
    @ba = TypeBA.new
    @c  = TypeC.new
  end
  it 'handles duplicate includes' do
    expect( @a.foobar     ).to eq 'A'
    expect( @a.foobar('Q')).to eq 'QA'
    expect( @b.foobar     ).to eq 'AB'
    expect( @b.foobar('Q')).to eq 'QAB'
    expect(@ab.foobar     ).to eq 'AB'
    expect(@ba.foobar     ).to eq 'ABX'
    expect( @c.foobar     ).to eq 'ABXY'
  end
end
