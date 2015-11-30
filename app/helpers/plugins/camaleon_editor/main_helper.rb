module Plugins::CamaleonEditor::MainHelper
  include Plugins::CamaleonEditor::PrivateHelper
  def self.included(klass)
    # klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end
end
