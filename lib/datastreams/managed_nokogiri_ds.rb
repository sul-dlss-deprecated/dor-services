class ActiveFedora::ManagedNokogiriDatastream < ActiveFedora::NokogiriDatastream 
  
  def initialize *args
    super(*args)
    self.control_group = 'M'
  end
  
end