# frozen_string_literal: true

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
    append_asset_libraries({ admin_grid_editor: { js:  ['plugins/camaleon_editor/admin/editor-manifest.js'],
                                                  css: [plugin_gem_asset('admin/grid-editor-manifest.css',
                                                                         'camaleon_editor')] } })
  end

  # loaded for frontend requests
  def camaleon_editor_front
    callback = lambda { |_args, _attrs|
      append_asset_libraries({ front_grid_editor: { css: [plugin_gem_asset('front/basic.css', 'camaleon_editor')] } })
    }
    shortcode_add('grid_editor', callback)
  end
end
