module Dor
  
  class Exception < ::Exception; end
  class ParameterError < Exception; end
  class DuplicateIdError < Exception
    attr_reader :pid
    
    def initialize(pid)
      @pid = pid
    end
  end
  # Raised by utils/druid_utils
  class SameContentExistsError < Exception; end
  class DifferentContentExistsError < Exception; end
end
