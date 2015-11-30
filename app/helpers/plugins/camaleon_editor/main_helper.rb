module Plugins::CamaleonEditor::MainHelper
  include PluginCamaleonEditorPrivateHelper
  def self.included(klass)
    # klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end
end
