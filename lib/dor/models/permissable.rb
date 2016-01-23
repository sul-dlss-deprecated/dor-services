module Dor
  module Permissable
    extend ActiveSupport::Concern

    # General documentation about roles and permissions is on SUL Consul at
    # https://consul.stanford.edu/display/chimera/Repository+Roles+and+Permissions
    # All these constants are frozen arrays so the methods that use them can
    # easily add them to return arrays.
    SDR_ADMINS = %w(sdr-administrator).freeze
    SDR_MANAGERS = %w(sdr-manager).freeze
    SDR_VIEWERS = %w(sdr-viewer).freeze

    APO_MANAGERS = %w(dor-apo-manager).freeze
    APO_DEPOSITORS = %w(dor-apo-depositor).freeze
    APO_METADATA = %w(dor-apo-metadata).freeze
    APO_VIEWERS = %w(dor-apo-viewer).freeze

    # A complete set of known roles.  This can be used by clients to
    # inspect all the possible roles available.
    KNOWN_ROLES = (
      SDR_ADMINS + SDR_MANAGERS + SDR_VIEWERS +
      APO_MANAGERS + APO_DEPOSITORS + APO_METADATA + APO_VIEWERS
    ).freeze

    # ---
    # APO permissions

    def can_create_apo?(roles)
      intersect roles, roles_which_create_apo
    end

    def can_manage_apo?(roles)
      intersect roles, roles_which_manage_apo
    end

    def can_manage_collections?(roles)
      intersect roles, roles_which_manage_collections
    end

    def can_manage_roles?(roles)
      intersect roles, roles_which_manage_roles
    end

    def can_manage_sets?(roles)
      intersect roles, roles_which_manage_sets
    end

    def can_release_objects?(roles)
      intersect roles, roles_which_release_objects
    end

    # ---
    # Item permissions

    def can_manage_item?(roles)
      intersect roles, roles_which_manage_item
    end

    def can_register_item?(roles)
      intersect roles, roles_which_register_item
    end

    def can_manage_desc_metadata?(roles)
      intersect roles, roles_which_manage_desc_md
    end

    def can_manage_system_metadata?(roles)
      intersect roles, roles_which_manage_sys_md
    end

    def can_manage_contents?(roles)
      intersect roles, roles_which_manage_contents
    end

    def can_manage_rights?(roles)
      intersect roles, roles_which_manage_rights
    end

    def can_manage_workflows?(roles)
      intersect roles, roles_which_manage_workflows
    end

    def can_manage_embargo?(roles)
      intersect roles, roles_which_manage_embargo
    end

    # ---
    # Common viewing permissions

    def can_view_content?(roles)
      intersect roles, roles_which_view_content
    end

    def can_view_metadata?(roles)
      intersect roles, roles_which_view_metadata
    end

    private

    # ---
    # APO roles

    def roles_which_create_apo
      SDR_ADMINS + SDR_MANAGERS
    end

    def roles_which_manage_apo
      SDR_ADMINS + SDR_MANAGERS + APO_MANAGERS
    end

    # When more granular roles are defined for APOs, these aliases
    # could be redefined as stand-alone methods.
    alias_method :roles_which_manage_roles, :roles_which_manage_apo
    alias_method :roles_which_manage_collections, :roles_which_manage_apo
    alias_method :roles_which_manage_sets, :roles_which_manage_apo

    def roles_which_release_objects
      SDR_ADMINS + SDR_MANAGERS + APO_MANAGERS + APO_DEPOSITORS
    end

    # ---
    # Item roles

    def roles_which_manage_item
      # exclude SDR_MANAGERS
      SDR_ADMINS + APO_MANAGERS + APO_DEPOSITORS
    end

    def roles_which_manage_desc_md
      SDR_ADMINS + APO_MANAGERS + APO_DEPOSITORS + APO_METADATA
    end

    # When more granular management roles are defined, these aliases
    # should be redefined as stand-alone methods.
    alias_method :roles_which_register_item, :roles_which_manage_item
    alias_method :roles_which_manage_sys_md, :roles_which_manage_item
    alias_method :roles_which_manage_contents, :roles_which_manage_item
    alias_method :roles_which_manage_rights, :roles_which_manage_item
    alias_method :roles_which_manage_workflows, :roles_which_manage_item
    alias_method :roles_which_manage_embargo, :roles_which_manage_item

    # ---
    # Viewer roles (apply to both APO and Item)

    # All roles can view metadata
    def roles_which_view_metadata
      KNOWN_ROLES
    end

    # Only SDR_MANAGERS cannot view content
    def roles_which_view_content
      SDR_ADMINS + SDR_VIEWERS +
      APO_MANAGERS + APO_DEPOSITORS + APO_METADATA + APO_VIEWERS
    end

    def intersect(arr1, arr2)
      (arr1 & arr2).length > 0
    end
  end
end
