# frozen_string_literal: true

# The plugin's grid_editor shortcode must be declared to Camaleon's boot-time ShortcodeRegistry, so
# the save-time content-shortcode gate can detect [grid_editor ...] in authored content (the
# per-request shortcode list is empty in the admin save path).
RSpec.describe 'grid_editor shortcode registration', type: :model do
  it 'declares grid_editor to the boot-time shortcode registry' do
    expect(CamaleonCms::ShortcodeRegistry.names).to include('grid_editor')
  end

  it 'detects grid_editor content as a gated shortcode' do
    expect(CamaleonCms::ShortcodeRegistry.content_has_shortcode?("<div>[grid_editor data='x']</div>")).to be(true)
  end
end
