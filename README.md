[<img src="https://travis-ci.org/sul-dlss/dor-services.png"/>](http://travis-ci.org/sul-dlss/dor-services)

# dor-services

Require the following:

    require 'dor-services'

Configuration is handled through the `Dor::Config` object:

```ruby
Dor::Config.configure do
  # Basic DOR configuration
  fedora.url = 'https://dor-dev.stanford.edu/fedora'
  gsearch.url = 'http://dor-dev.stanford.edu/solr'

  # If using SSL certificates
  ssl do
    cert_file = File.dirname(__FILE__) + '/../certs/dummy.crt'
    key_file = File.dirname(__FILE__) + '/../certs/dummy.key'
    key_pass = 'dummy'
  end

  # If using SURI service
  suri do
    mint_ids = true
    url = 'http://some.suri.host:8080'
    id_namespace = 'druid'
    user = 'suriuser'
    password = 'suripword'
  end
end
```

Values can also be configured individually:

    Dor::Config.suri.mint_ids(true)

## Development and release process

See the consul page for it at:
https://consul.stanford.edu/display/dlssdev/How+to+release+and+use+a+DLSS+gem+to+the+gemserver

## Console

You can start a pry session with the dor-services gem loaded by executing the
script at

    ./script/console

It will need the following in order to execute:

    ./config/dev_console_env.rb
    ./config/certs/robots-dor-dev.crt
    ./config/certs/robots-dor-dev.key

You can basically copy the
`sul-lyberservices-dev:common-accessioning/current/config/environments/development.rb` file and the certs from there too

This is located in the `./script` subdirectory so that it does not get
installed by clients of the gem

## Releases

*   **0.1.1** Initial release with basic object registration and query_by_id functionality
*   **0.1.3** Replace gsearch/solr with risearch in query_by_id
*   **0.1.4** Change calling signature of :source_id hash parameter in register_object
*   **0.1.5** Remove content model from required parameters for registration; fixed indenting of XML datastreams
*   **0.2.0** Implemented Dor::WorkflowService as a passthrough to existing DOR web services
*   **0.2.1** Added support for :object_admin_class parameter in register_object
*   **0.3.0** Added MetadataService to fetch metadata from various sources (currently Symphony and eXist/MD Toolkit)
*   **1.0.0**
    *   Richer response from Registration Service
    *   MD Toolkit metadata handler work with non-MODS metadata

*   **1.0.1** Changed descMetadata fetcher to pull based on best available "other ID" instead of "source ID"
*   **1.0.2** Added caching of metadata (250 records, 5 minute timeout)
*   **1.0.3** Fix bug in build_datastream
*   **1.1.0** Switched from hand-rolled configuration object to ModCons-based configuration object
*   **1.1.1** Use SSL certificates for gsearch
*   **1.1.2** Hotfix for missing methods in Dor::Item
*   **1.1.3** Hotfix for misspelled objectCreator in registration service
*   **1.1.4** Hotfix for malformed URL stem in Workflow service
*   **1.1.5** Hotfix for issue in which tempfile was not being flushed before copy (in Dor::Item#shelve)
*   **1.2.0** Add `Dor::Item#initiate_apo_workflow()` to initiate named workflows from the APO
*   **1.2.1** Add basic TEI header support to `Dor::Item#generate_dublin_core`;
    switch from guid to uuidtools for UUID creation
*   **1.3.0** Added Druid class for calculation and manipulation of DRUID trees
*   **1.3.1** Rebased workflow changes that were left out of 1.3.0
*   **1.4.0** Add reindex method to Dor::Base
*   **1.4.1**
    *   Prettify/shrink public XML
    *   Improve `Dor::SearchService.gsearch` parameter handling

*   **1.5.0**
    *   Add certificate-aware RSolr::Connection class
    *   Add `Dor::Base.touch(druid)` to trigger reindexing without ActiveFedora

*   **1.6.0**
    *   Implement SdrIngestService and CleanupService
    *   Turn off ActiveFedora's automatic SOLR updating
    *   Add MD Toolkit metadata handler workaround for NullPointerException in
        eXist

*   **1.6.1** Fixed configuration of export directory in specs
*   **1.6.2** Fixed configuration reference in cleanup spec
*   **1.6.3** Simplify & speed up MD Toolkit metadata handler queries
*   **1.6.4** Fix MetadataHandler spec tests to match new MD Toolkit
    implementation
*   **1.7.0**
    *   LYBERSTRUCTURE-138 Registration - read item-level agreementId from APO
    *   LYBERSTRUCTURE-139 Registration - read relationships information from
        APO

*   **1.7.1**
    *   Minor tweaks to FOXML, identity metadata, and content metadata
    *   Normalize whitespace in descriptive metadata text fields

*   **1.7.2** Add auto-updating Dor::Config.fedora.safeurl (url with user/pass
    stripped)
*   **2.0.0** **Major Release:**
    *   Service additions: SdrIngest, JHove, Cleanup, ProvenanceMetadata
    *   New functionality: `Dor::SearchService#reindex(*pids)` uses gsearch's
        XSLT internally
    *   Code cleanup: Merged redundant `RestClient::Resource.new()` calls into a
        single #client method on Dor::Config.fedora and Dor::Config.gsearch
    *   README formatting: Looks better in HTML, worse in text.

*   **2.1.0** Dor::Item can now build technicalMetadata datastream
*   **2.1.1** Workaround for misbehaving `ActiveFedora::Base#datastream_names`
*   **2.1.2** Add technicalMetadata to sdr_ingest_transfer's datastream list
*   **2.2.0**
    *   New Datastreams: EmbargoMetadataDS and EventsDS
    *   New Module: Dor::Embargo.  Can be mixed in to Dor objects to add
        embargo functionality
    *   Gsearch xslt now indexes the embargoMetadata datastream

*   **2.2.1** Mark EmbargoMetadataDS and EventsDS as dirty when their setters
    are used
*   **2.2.2** Mark rightsMetadata as dirty when embargo is lifted
*   **2.3.0**
    *   `Dor::WorkflowService#get_lifecycle`
    *   Only publish metadata if rightsMetadata says so

*   **2.3.1** Publish public xml when <access type="discover">
*   **2.4.0**
    *   Reified workflow
    *   Cleaner MODS2DC transformation
    *   More robust IdentityMetadataDS object
    *   Indexing tweaks

*   **2.4.1**
    *   Improve `Dor::Base.get_foxml()`
    *   Index lifecycle directly from workflow processes instead of retrieving
        lifecycle XML

*   **2.4.2** Restrict gsearch stylesheet to pulling XML datastreams
*   **2.5.0** Large-scale refactor of gsearch stylesheet and indexing methods
*   **2.5.1** Use the gsearch REST service for Dor::SearchService.reindex()
*   **2.5.2** Fix xalan/saxon/libxslt issues in gsearch XSLT
*   **2.5.3**
    *   Handle empty <lifecycle> queries instead of a 404 exception
    *   Hotfix for public xml publishing from 2.3.1

*   **2.5.4** Lock ActiveFedora at 3.0.4 for the time being -- higher versions
    expect a fedora.yml file that we don't provide
*   **2.6.0** First usable release of reified workflow objects
*   **2.6.1**
    *   Publish MODS descMetadata alongside public XML
    *   gsearch style sheet updates

*   **2.6.2** Add relationship metadata (straight RELS-EXT clone) to public
    XML
*   **2.6.3** Filter irrelevant relationships out of public XML
*   **3.0.0**
    *   Large-scale refactor of gem architecture
    *   Built directly on ActiveFedora 3.3 and Solrizer
        *   Phasing out fedora-gsearch as the primary index
        *   Proper solrization of content model and relationship assertions

    *   Configuration change from mod-cons to confstruct
        *   Affects dor-services development, but should be invisible to
            consumers

    *   Dor::Item split into multiple ActiveSupport::Concern modules
        *   Each Concern provides the structure and methods to deal with one
            particular aspect of the item:
            *   Describable: Descriptive Metadata
            *   Embargoable: Embargoes
            *   Governable: Admin. Policies
            *   Identifiable: Identity Metadata
            *   Itemizable: Content Metadata
            *   Preservable: Preservation
            *   Processable: Workflow
            *   Publishable: Publishing
            *   Shelvable: Shelving

    *   Introduction of Dor::Collection and Dor::Set models
    *   Support for unified "workflows" datastream as well as separate xxxxxxxWF datastreams
    *   Proper datastream types for Administrative, Content, Descriptive,
        Embargo, Events, Identity, Role, and Workflow metadata. Most classes
        now use OM terminologies and automatic Solrizer term extraction.

*   **3.0.1** Corrected Gemfile to remove local `active_fedora`
*   **3.0.2** Added in missing default configuration files
*   **3.0.3** Added config directory to gemspec
*   **3.0.4**
    *   Fix inheritance bug in solrization methods
    *   Declare contentMetadata as control group 'M'

*   **3.0.5**
    *   Replace `Config#define_custom_fields!` and `Config#after_config!` with real callbacks
    *   Make post-configuration callback more tolerant of omitted blocks and values

*   **3.0.6**
    *   Update dependencies to ActiveFedora ~>3.3.2 and confstruct >=0.2.2
    *   Improve indexing of workflows and events datastreams
    *   LYBERSTRUCTURE-108 Name formatting error in DC derived from MODS
    *   LYBERSTRUCTURE-194 MODS2DC transform -- support repository, collection
        and location mapping to published DC

*   **3.1.0**
    *   Restructured directory layout: Now organized into datastreams, models,
        services, workflow, and utils
    *   Move Dor-specific datastreams into `Dor::*` namespace
    *   Move `Dor::WorkflowService.get_objects_for_workstep` from lyber-core
    *   Move remaining registration business logic from Argo's registration
        controller to Dor::RegistrationService
    *   Add dor-indexer (console) and dor-indexerd (daemon) executables to
        reindex objects based on Fedora messages

*   **3.1.1** Remove inline solrization of relationship referents
*   **3.2.0**
    *   REV-23 Have datastream builders pick up content from workspace if present
    *   Retrofit for ActiveFedora 3.3.2 and 4.0 compatibility
    *   Improve indexing of IdentityMetadata/sourceId
    *   Improved tests
    *   Bug fixes

*   **3.3.0**
    *   Added the Assembleable concern
    *   DruidUtils enhancements to create a link as the final node of a druid tree

*   **3.3.1** Indexing and SearchService fixes
*   **3.3.2** (Unreleased)
*   **3.3.3**
    *   Dor::SuriService.mint_ids() can now generate multiple PIDs with a single call
    *   Indexing/Model loading fixes for ActiveFedora 4.0.0rc15

*   **3.3.4**
    *   Properly convert unqualified MODS dates to DC
    *   Minor bug fixes

*   **3.3.5**
    *   Move SSL config options from fedora block to new ssl block
    *   Add Dor::Config#sanitize and Dor::Config#autoconfigure
    *   Fix 'repository'/'repo' conflicts in workflow definition/process objects
    *   Add status booleans (completed? error? blocked? waiting? ready?) to workflow processes
    *   Registration bugfix: Don't try to save datastreams if there's no real object underneath

*   **3.3.6** Recover gracefully (with a warning) from `ActiveFedora::Base.load_from_solr()` exceptions
*   **3.3.7**
    *   Load workflows datastream XML directly from workflow service
    *   Use ActiveFedora 4.0.0.rc20 until final 4.0.0 release
    *   Minor solr indexing fixes

*   **3.4.0**
    *   Switch from explicit load to autoload for faster startup
    *   Add Dor::Config.stomp (and Dor::Config.stomp.client)
    *   Add resource-index-based Dor::SearchService.iterate_over_pids

*   **3.4.1**
    *   Fix field name bug in WorkflowObject.find_by_name
    *   Make the indexer queue/worker friendly
    *   Update tests to work with ActiveFedora 4.0
    *   Improve test stubbing to fix false (order-dependent) failures

*   **3.4.2**
    *   WorkflowService now requires active_support/core_ext explicitly in
        order for robots to start

*   **3.5.0**
    *   Update active-fedora dependency to final 4.0.0 release
    *   ARGO-24 Show all name parts for author/creator in citation
    *   LYBERSTRUCTURE-205 Deprecate contentMetadata "format" attribute in Common Accessioning
    *   LYBERSTRUCTURE-215 Update objects to a single "workflows" datastream, drop workflow specific datastreams
    *   LYBERSTRUCTURE-224 Drop <agreementId> from identityMetadata; SDR will verify APO instead
    *   LYBERSTRUCTURE-222 identityMetadata - drop AdminPolicy tag and rely on isGovernedBy relationship
    *   First round of object remediation using Upgradable concern
    *   Add Upgradable concern
    *   Index workflow ready/blocked states
    *   Add workflow name and archive totals to WorkflowObject index

*   **3.5.1** Hotfix for solrizing malformed tags
*   **3.5.2**
    *   Fix empty datastream check in Dor::Processable#build_datastream to
        include cases where the content is equivalent to the default XML
        template for the datastream class

*   **3.6.0**
    *   Add keep-alive heartbeat to dor-indexer
    *   Add contentMetadata/@type migration
    *   Take steps to ensure Upgradables idempotence
    *   Record remediation migrations in events datastream

*   **3.6.1**
    *   Restore adminPolicy to identityMetadataDS (for backward compatibility)
    *   Ensure correct content model assertions
    *   Remediated objects are tagged with the version of dor-services that updated them

*   **3.6.2** Minor migration and indexing bug fixes
*   **3.6.3** Hotfix for `Describable#generate_dublin_core` raising the wrong
    kind of exception
*   **3.6.4** Add abstract to descMetadata
*   **3.7.0** Use Moab versioning service in shelving
*   **3.7.1** Make cm_inv_diff cache aspect-specific
*   **3.7.2** Add net-sftp dependency
*   **3.8.0**
    *   Versioning support for sdr-ingest-transfer robot
    *   Embargo release copies all <access type="read"> nodes from embargoMetadata to rightsMetadata

*   **3.8.1** (Unreleased)
*   **3.8.2** SDR Ingest service hotfixes
*   **3.8.3** Fix Timeout...rescue bug in dor-indexer
*   **3.8.4** More robust exception handling in RegistrationService and
    dor-indexer
*   **3.9.0**
    *   Use options hash for Dor::WorkflowService update workflow and error methods
    *   Move REST registration logic from Argo's ObjectsController#create to
        Dor::RegistrationService#create_from_request
    *   Monkey patch ActiveFedora::RelsExtDatastream.short_predicate to create
        missing mappings on the fly.

*   **3.10.0** Added support for setting rights when registering an object.
*   **3.10.1** Fixed a 1.87->1.93 syntax deprication issue
*   **3.10.2** Changed the method for setting the rightsMetadata stream to trigger a save
*   **3.10.3** Debugging failure to save rights metadata
*   **3.10.4** Found the location where the report parameter from argo was being lost
*   **3.10.5** Corrected the Stanford entry in rights metadata, and truncate the fedora label if it is too long
*   **3.10.6** Removed a remnant from the previous change
*   **3.10.7** Source id is now a required parameter for item registration
*   **3.10.8** A descriptive metadata stream with basic mods created from the
    label can be created in item registration
*   **3.11.0**
    *   Dor::WorkflowObject.initial_workflow creates workflow xml from workflow definition objects
    *   Added Versionable concern

*   **3.11.1** Include versionable concern with Dor::Item
*   **3.11.2** Call correct workflow initialization method when opening a new version
*   **3.11.3** Use correct Dor::Exception when opening a new version
*   **3.11.4** Add a new 'tags' method to the item, which will return an array of tags; also add a new method to get the tagged content-type
*   **3.11.5** Bump required version of druid-tools gem to 0.2.1
*   **3.12.0** Added some update services for identity metadata, rights metadata, and desc metadata
*   **3.12.2**
        - Autoload the TechnicalMetadataService whenever dor-services is required
        - versionMetadata added at object creation and remediation

*   **3.13.0** Create a Dor::DigitalStacksService.stacks_storage_dir method
*   **3.13.1** Patch to create workflows correctly for sdr
*   **3.13.2** Embargo Update should update the datastream</b>
*   **3.13.3** Another embargo fix</b>
*   **3.13.4** initiate_apo_workflow does not create workflows datastream when
    an object is new</b>
*   **3.14.0**
    *   technicalMetadata bugfixes
    *   use sul-gems as new Gemfile source

*   **3.14.1** Removed dor indexer and registration no longer requires a valid
    label if md source is mdtoolkit or symphony"
*   **3.14.6** Fixed a 1.9 incompatibility that was breaking things in argo
*   **3.15.0** Use new dor-workflow-service gem
*   **3.16.0** Add methods to query and close object versions
*   **3.16.5** A number of changes to the to_solr methods to remove unneeded
    stuff and add stuff that makes loading facets more efficient"
*   **3.16.8** Added the ability to create a status string for and object and added that as an indexed field
*   **3.16.9** Using moab-versioning >= 1.1.3
*   **3.17.0** Versionable#close_version now archives versioningWF workflow. 
    Requires a new Dor::Config param, dor_services.url
*   **3.17.1** Added roles and a solr field for the first shelved image in an object
*   **3.17.2** Fixed a typo in get_collection_title and some tests that failed to catch the typo
*   **3.17.3** TechnicalMetadataService and SdrIngestService now find content ok.  Updated gem dependencies
*   **3.17.4** SdrIngestService was creating moab manifests that were missing SHA256 checksums
*   **3.17.5** AddCollectionReference was causing the ng_xml for the desc
    metadata in the current item instance to be polluted
*   **3.17.6** Added a predicate mapping for hydrus
*   **3.17.7** SdrIngestService was not handling case when new version has no new content files.
*   **3.17.9** Now extracts all datastreams from Fedora even if file exists on disk.
*   **3.17.10** SdrIngestService was not handling case when object has no contentMetadata.
*   **3.17.11** Workflow was only set up to work with items from the dor repo.
*   **3.17.12** BuildDatastream can now require the datastream be populated and raise an exception if it isnt
*   **3.17.13** Fixes all known issues caused by nokogiri 1.56
*   **3.18.0** Dor::Versionable.close_version changes to deal with tag and description
*   **3.18.4** The exception caused by a lack of desc metadata is logged silently
*   **3.19.0** Optional params for version number and starting accessioning when archiving workflow
*   **3.21.1** Allow user to specify resource type when adding a resource to content metadata
*   **3.22.0** Remove assembly directories on cleanup
*   **3.23.0** Always generate brand new provenanceMetadata
*   **3.24.0** APO editing functionality
*   **3.24.1** Closing a version no longer archives a workflow
*   **3.24.2** Undoing v3.24.1: closing a version does archive a workflow
*   **4.0.0** ActiveFedora 5 and ruby 1.9.3
*   **4.0.1** Index accessioning errors, expose workflow notes
*   **4.0.2** APO rights work with capitalization
*   **4.0.5** Support for workflow priority
*   **4.1.1** Index gryphondor fields into the argo solr index
*   **4.1.2** Set workflow priority during item registration
*   **4.1.7** Cache workflow information for faster indexing
*   **4.2.0** Nokogiri 1.6.0
*   **4.2.1** Check for versionmetadata datastream when doing sdr-ingest-transfer
*   **4.2.3** Fix an exception that occured when a version had no description
*   **4.3.0** Add some missing hydrus solr fields
*   **4.3.2** Bug fixes and refactoring of object status logic
*   **4.4.3** Use moab 1.3.1
*   **4.4.6** call super in Editable.to_solr
*   **4.4.7** Use OM to index APO data
*   **4.4.8** Fix a broken migration
*   **4.4.9** add remote publishing via dor-services-app
*   **4.4.10**
*   **4.4.11**
*   **4.4.12**
*   **4.4.13**
*   **4.4.14** Major cleanup of Gemfiles and README, passes all tests
*   **4.4.15** Added support for Geoable and GeoMetadataDS
*   **4.5.0** Added workflow transactional support when closing a version.  Eliminate caching of diff cache
*   **4.12.2**  Updating to MOAB Versioning 1.3.3


## Copyright

Copyright (c) 2014 Stanford University Library. See LICENSE for details.
