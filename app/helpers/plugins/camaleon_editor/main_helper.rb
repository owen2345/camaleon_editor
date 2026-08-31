# frozen_string_literal: true

# Camaleon plugin helper carrying the hook methods camaleon_plugin.json names: the activation
# lifecycle, the admin post-form asset injection and the grid_editor frontend shortcode.
module Plugins::CamaleonEditor::MainHelper
  # The plugin's two default-off permissions (admins always pass). Single source of truth for the
  # roles-form checkbox keys, the controller gates and the asset gate, so they cannot drift.
  # PERMISSION_USE: use the editor (apply templates, get the toolbar button).
  # PERMISSION_MANAGE: curate the shared template library (create/edit/delete).
  PERMISSION_USE = :camaleon_editor
  PERMISSION_MANAGE = :camaleon_editor_templates

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def camaleon_editor_on_active(plugin); end

  # here all actions on going to inactive
  # plugin: plugin model
  def camaleon_editor_on_inactive(plugin); end

  # here all actions to upgrade for a new version
  # plugin: plugin model
  def camaleon_editor_on_upgrade(plugin); end

  # for post form editor
  def camaleon_editor_admin
    # append_asset_libraries(
    #   { bootstrap_editor:{ js: [plugin_gem_asset("grid-editor.js")], css: [plugin_gem_asset("grid-editor.css")] } }
    # )
  end

  # for post form editor
  def camaleon_editor_post_form(_args)
    # Only for users granted the editor-use permission: without it the grid-editor button would call
    # admin endpoints that refuse the user anyway, so they get the plain editor instead.
    return unless can?(:manage, PERMISSION_USE)

    append_asset_libraries({ admin_grid_editor: { js: ['plugins/camaleon_editor/admin/editor-manifest.js'],
                                                  css: [plugin_gem_asset('admin/grid-editor-manifest.css',
                                                                         'camaleon_editor')] } })
  end

  # registers the plugin's two permissions in the admin roles form (Users > Roles). Both are off by
  # default and admins always pass.
  def camaleon_editor_available_user_roles_list(args)
    roles = args[:roles_list]
    return unless roles.is_a?(Hash) && roles[:manager].is_a?(Array)

    new_entries = camaleon_editor_role_permissions.reject do |entry|
      roles[:manager].any? { |role| role[:key] == entry[:key] }
    end
    return if new_entries.empty?

    # cama_get_roles_values hands us the shared, shallowly-frozen CamaleonCms::UserRole::ROLES constant
    # itself; append to a copy and reassign (the helper reads args[:roles_list] back) so the permissions
    # are not permanently pushed onto the process-global constant on every roles-form render.
    args[:roles_list] = roles.merge(manager: roles[:manager] + new_entries)
  end

  # The plugin's two role-form permission entries, in Camaleon's { key:, label:, description: } shape.
  def camaleon_editor_role_permissions
    [
      { key: PERMISSION_USE.to_s,
        label: I18n.t('camaleon_editor.permission.label'),
        description: I18n.t('camaleon_editor.permission.description') },
      { key: PERMISSION_MANAGE.to_s,
        label: I18n.t('camaleon_editor.permission.manage_label'),
        description: I18n.t('camaleon_editor.permission.manage_description') }
    ]
  end

  # loaded for frontend requests
  def camaleon_editor_front
    callback = lambda { |_args, _attrs|
      append_asset_libraries({ front_grid_editor: { css: [plugin_gem_asset('front/basic.css', 'camaleon_editor')] } })
    }
    shortcode_add('grid_editor', callback)
  end
end
