# frozen_string_literal: true

# The style settings panel is rendered on the server, its strings read from the plugin's own tree by
# camaleon_editor_t: in an admin language the plugin does not ship, the helper answers in English.
RSpec.describe 'the style settings panel strings', type: :model do
  # Every key the view asks for
  def view_keys
    view = Rails.root.join('../../app/views/plugins/camaleon_editor/admin/style_settings.html.erb').read
    view.scan(/camaleon_editor_t\(["']style_settings\.(\w+)["']\)/).flatten.uniq
  end

  it 'finds the keys the view asks for' do
    expect(view_keys).to include('background_image', 'position', 'left_top', 'border', 'padding')
  end

  it 'ships every one of them in every language' do
    expect_shipped_translations('camaleon_editor.style_settings', view_keys)
  end
end
