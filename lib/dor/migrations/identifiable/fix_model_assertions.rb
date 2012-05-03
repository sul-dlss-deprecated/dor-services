Dor::Identifiable.on_upgrade '3.6.1', 'Assert correct models' do |obj|
  if obj.relationships.any? { |r| r.predicate.to_s == 'info:fedora/fedora-system:def/model#hasModel' && r.object.to_s == 'info:fedora/hydra:commonMetadata' }
    obj.remove_relationship :has_model, 'info:fedora/hydra:commonMetadata'
  end
  
  unless obj.relationships.predicates.any? { |p| p.to_s == 'info:fedora/fedora-system:def/model#hasModel' }
    obj.assert_content_model
  end
  obj.rels_ext.dirty?
end
