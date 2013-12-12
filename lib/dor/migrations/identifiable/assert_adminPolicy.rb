Dor::Identifiable.on_upgrade '3.5.0', 'Assert hydra:isGovernedBy' do |obj|
  # Assign hydra:isGovernedBy based on identityMetadata/adminPolicy
  if obj.admin_policy_object.nil?
    apo_id = obj.identityMetadata.adminPolicy.first
    apo_id.present? && obj.admin_policy_object = Dor.find(apo_id) unless apo_id.nil?
  else
    false
  end
end