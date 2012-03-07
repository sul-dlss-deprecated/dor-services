class Druid
  attr_accessor :druid
  
  DRUID_PATTERN = /^(?:druid:)?([a-z]{2})(\d{3})([a-z]{2})(\d{4})$/
  def initialize(druid)
    if druid !~ DRUID_PATTERN
      raise ArgumentError, "Invalid DRUID: #{druid}"
    end
    @druid = druid
  end
  
  def id
    @druid.scan(/^(?:druid:)?(.+)$/).flatten.last
  end
  
  def tree
    @druid.scan(DRUID_PATTERN).flatten
  end
  
  def path(base=nil)
    File.join(*([base,tree].compact))
  end
  
  def mkdir(base)
    FileUtils.mkdir_p(path(base))
  end
  
  def rmdir(base)
    parts = tree
    while parts.length > 0
      dir = File.join(base, *parts)
      begin
        FileUtils.rm(File.join(dir,'.DS_Store'), :force => true)
        FileUtils.rmdir(dir)
      rescue Errno::ENOTEMPTY
        break
      end
      parts.pop
    end
  end
end
