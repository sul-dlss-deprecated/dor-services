# Copied from common-accessioning config/environments

cert_dir = File.join(File.dirname(__FILE__), ".", "certs")

Dor::Config.configure do
  fedora do
    url 'https://sul-dor-dev.stanford.edu/fedora'
  end

  ssl do
    cert_file File.join(cert_dir,"robots-dor-dev.crt")
    key_file File.join(cert_dir,"robots-dor-dev.key")
    key_pass ''
  end

  suri do
    mint_ids true
    id_namespace 'druid'
    url 'https://lyberservices-dev.stanford.edu'
    user 'labware'
    pass 'lyberteam'
  end

  metadata do
    exist.url 'http://viewer:l3l%40nd@lyberapps-dev.stanford.edu/exist/rest/'
    catalog.url 'http://lyberservices-prod.stanford.edu/catalog/mods'
  end

  stacks do
    document_cache_storage_root '/home/lyberadmin/document_cache'
    document_cache_host 'purl-dev.stanford.edu'
    document_cache_user 'lyberadmin'
    local_workspace_root '/dor/workspace'
    storage_root '/stacks'
    host 'stacks-dev.stanford.edu'
    user 'lyberadmin'
  end

  gsearch.url 'https://dor-dev.stanford.edu/solr/gsearch'
  solrizer.url 'https://dor-dev.stanford.edu/solr'
  workflow.url 'https://lyberservices-dev.stanford.edu/workflow/'
  dor_services.url 'https://dorAdmin:dorAdmin@sul-lyberservices-dev.stanford.edu/dor/v1'

  cleanup do
    local_workspace_root '/dor/workspace'
    local_export_home '/dor/export'
  end

  sdr do
    local_workspace_root '/dor/workspace'
    local_export_home '/dor/export'
    datastreams do
      contentMetadata 'required'
      descMetadata 'required'
      identityMetadata 'required'
      provenanceMetadata 'required'
      relationshipMetadata 'required'
      rightsMetadata 'optional'
      sourceMetadata 'optional'
    end
  end

  accessioning_robot_sleep_time 30

end