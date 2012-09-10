module Dor
  class RelationshipService
	    class << self
				def add_collection(object_druid,collection_druid)
					obj=Dor::Item.find(object_druid, :light_weigth => true)
						obj.add_relationship_by_name('collection','info:fedora/'+collection_druid)
				end 
				def remove_collection(object_druid, collection_druid)
					obj=Dor::Item.find(object_druid, :light_weigth => true)
					obj.remove_relationship_by_name('collection','info:fedora/'+collection_druid)

				end
			end
		end
end
