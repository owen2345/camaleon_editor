# frozen_string_literal: true

# init_plugin (base class) does current_site.plugins.first_or_create before authorization. The plugin
# re-orders so authorize_plugin runs first, so an authenticated but unauthorized user cannot seed a
# plugins row for a site merely by requesting the URL.
RSpec.describe 'authorization runs before init_plugin side effects' do
  init_site

  # The site must have no row of the plugin: with a row, the request can add none, and the example
  # shows nothing. The shared site of the suite has the plugin (spec/support/shared_site.rb).
  before do
    store_current_site(@site)
    @site.plugins.where(slug: 'camaleon_editor').destroy_all
  end

  it 'creates no plugins row for an unauthorized user hitting the endpoint' do
    sign_in_as(user_with_manager_grants({}, 'nobody'), site: @site)

    expect do
      get '/admin/plugins/camaleon_editor/grid_editor'
    end.not_to(change { @site.plugins.where(slug: 'camaleon_editor').count }.from(0))

    expect(response.location).to include('/admin/dashboard')
    expect(flash[:error]).to be_present
  end
end
