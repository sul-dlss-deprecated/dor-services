Dor::Identifiable.on_upgrade '3.5.0' do |obj|
  # Assign hydra:isGovernedBy based on identityMetadata/adminPolicy
  if obj.admin_policy_object_ids.empty?
    apo_id = self.identityMetadata.adminPolicy.first
    obj.admin_policy_object_append("info:fedora/#{apo_id}") unless apo_id.nil?
    true
  else
    false
  end
end