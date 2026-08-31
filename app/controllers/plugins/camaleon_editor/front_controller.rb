# frozen_string_literal: true

# Frontend controller of the plugin. Frontend behavior is hook- and shortcode-driven (see
# MainHelper#camaleon_editor_front); no custom endpoints are exposed.
class Plugins::CamaleonEditor::FrontController < CamaleonCms::Apps::PluginsFrontController
  include Plugins::CamaleonEditor::MainHelper

  def index
    # actions for frontend module
  end

  # add custom methods below
end
