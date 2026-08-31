# frozen_string_literal: true

# Camaleon plugin helper carrying the hook methods camaleon_plugin.json names: the activation
# lifecycle, the admin post-form asset injection and the grid_editor frontend shortcode.
module Plugins::CamaleonEditor::MainHelper
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
    # Only for users granted the editor permission: without it the grid-editor button would call
    # admin endpoints that refuse the user anyway, so they get the plain editor instead.
    return unless can?(:manage, :camaleon_editor)

    append_asset_libraries({ admin_grid_editor: { js: ['plugins/camaleon_editor/admin/editor-manifest.js'],
                                                  css: [plugin_gem_asset('admin/grid-editor-manifest.css',
                                                                         'camaleon_editor')] } })
  end

  # registers the plugin's own permission in the admin roles form (Users > Roles). Granting it to a
  # role allows using the grid editor; it is off by default and admins always pass.
  def camaleon_editor_available_user_roles_list(args)
    args[:roles_list][:manager] << {
      key: 'camaleon_editor',
      label: I18n.t('camaleon_editor.permission.label', default: 'Visual grid editor'),
      description: I18n.t('camaleon_editor.permission.description',
                          default: 'Can switch the post editor to the grid editor and manage grid templates')
    }
  end

  # loaded for frontend requests
  def camaleon_editor_front
    callback = lambda { |_args, _attrs|
      append_asset_libraries({ front_grid_editor: { css: [plugin_gem_asset('front/basic.css', 'camaleon_editor')] } })
    }
    shortcode_add('grid_editor', callback)
  end
end
