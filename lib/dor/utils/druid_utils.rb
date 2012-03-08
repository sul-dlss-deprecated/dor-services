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
    new_path = path(base)
    if(File.symlink? new_path)
      raise Dor::DifferentContentExistsError, "Unable to create directory, link already exists: #{new_path}"
    end
    if(File.directory? new_path)
      raise Dor::SameContentExistsError, "The directory already exists: #{new_path}"
    end
    FileUtils.mkdir_p(new_path)
  end
  
  def mkdir_with_final_link(source, new_base)
    new_path = path(new_base)
    if(File.symlink? new_path)
      raise Dor::SameContentExistsError, "The link already exists: #{new_path}"
    end
    if(File.directory? new_path)
      raise Dor::DifferentContentExistsError, "Unable to create link, directory already exists: #{new_path}"
    end
    real_dirs = tree
    real_dirs.slice!(real_dirs.length - 1)
    real_path = File.join(new_base, real_dirs)
    FileUtils.mkdir_p(real_path)
    FileUtils.ln_s(source, new_path)
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
