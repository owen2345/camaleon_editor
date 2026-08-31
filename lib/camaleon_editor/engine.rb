# frozen_string_literal: true

module CamaleonEditor
  # Rails engine that mounts the plugin into a Camaleon CMS host and declares its boot-time shortcode.
  class Engine < ::Rails::Engine
    # Declare the plugin's shortcode to Camaleon's boot-time registry so the save-time
    # content-shortcode gate can detect [grid_editor ...] in authored content (the per-request
    # shortcode list is empty at an admin save). The render-time handler stays in
    # MainHelper#camaleon_editor_front (shortcode_add). Guarded so the plugin still loads against
    # camaleon_cms versions predating the registry.
    initializer 'camaleon_editor.register_shortcodes' do
      CamaleonCms::ShortcodeRegistry.register('grid_editor') if defined?(CamaleonCms::ShortcodeRegistry)
    end
  end
end
