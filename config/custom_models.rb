CamaleonCms::Site.class_eval do
  has_many :grid_templates, :class_name => "Plugins::CamaleonEditor::GridTemplate", foreign_key: :parent_id, dependent: :destroy
end
