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
  EDITOR_ASSETS_APPENDED = 'camaleon_editor.editor_assets_appended'

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

    camaleon_editor_append_editor_assets
  end

  # Loads the grid editor into the current admin page. The post-form hooks call it; an admin page of
  # a host app or another plugin that wants the editor on its own TinyMCE fields calls it too, so
  # the editor always arrives together with what it needs to know about the user.
  def camaleon_editor_append_editor_assets
    # once per request, whoever calls: the hook runs in the controller, a host page may call from a
    # view, and the request is what the two share
    return if request.env[EDITOR_ASSETS_APPENDED]

    # The editor builds its menu in the browser, so it has to be told which actions the server
    # would refuse this user: a refusal is a redirect, which the menu's modal would render as the
    # dashboard page. Asked before anything is appended. A boolean's to_s: nothing but a literal
    # true or false reaches the script.
    can_manage = (can?(:manage, PERMISSION_MANAGE) == true).to_s
    append_asset_libraries({ admin_grid_editor: { js: ['plugins/camaleon_editor/admin/editor-manifest.js'],
                                                  css: [plugin_gem_asset('admin/grid-editor-manifest.css',
                                                                         'camaleon_editor')] } })
    append_asset_content("<script>var cama_grid_editor_can_manage_templates = #{can_manage};</script>")
    # marked last: core runs a hook that raised a second time, and a mark set before the work would
    # make that second run skip what the first did not get to
    request.env[EDITOR_ASSETS_APPENDED] = true
  end

  # A string of the plugin's own for the admin panel. The plugin ships fewer languages than core,
  # which ships every admin language: where the plugin has no string for the current one, a core
  # string that says the same keeps the admin in their language, and the plugin's English is the last
  # resort. A string with no core equivalent - a warning core never gives - is called without a
  # core_key and goes straight to the plugin's English: a prompt that says less is not a translation.
  # The plugin's string is looked up without locale fallbacks, which would otherwise answer in English
  # before the core string got its turn.
  def camaleon_editor_t(key, core_key = nil)
    plugin_key = "camaleon_editor.#{key}"
    I18n.t(plugin_key, fallback: false, default: nil) ||
      (core_key && I18n.t(core_key, default: nil)) ||
      I18n.t(plugin_key, locale: :en)
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
