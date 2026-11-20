# frozen_string_literal: true

# camaleon_editor is not one of Camaleon's default plugins, so a site never gets it on install --
# activation is an explicit step (admin plugin manager, or plugin_install here). Installing runs the
# plugin's on_active hook; uninstalling runs on_inactive.
RSpec.describe 'camaleon_editor plugin activation', type: :model do
  context 'with a new site' do
    init_site(fresh: true)

    it 'is not auto-installed' do
      expect(@site.plugins.pluck(:slug)).not_to include('camaleon_editor')
    end
  end

  # The suite installs the plugin on its shared site (spec/support/shared_site.rb).
  context 'with the shared site' do
    init_site

    before do
      store_current_site(@site)
      plugin_uninstall('camaleon_editor')
    end

    it 'installs and activates for a site, running the on_active hook' do
      plugin_model = plugin_install('camaleon_editor')

      expect(plugin_model).to be_active
      expect(@site.plugins.active.pluck(:slug)).to include('camaleon_editor')
    end

    it 'deactivates again, running the on_inactive hook' do
      plugin_install('camaleon_editor')
      plugin_model = plugin_uninstall('camaleon_editor')

      expect(plugin_model).not_to be_active
      expect(@site.plugins.active.pluck(:slug)).not_to include('camaleon_editor')
    end
  end
end
