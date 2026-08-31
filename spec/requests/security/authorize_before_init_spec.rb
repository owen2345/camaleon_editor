# frozen_string_literal: true

# init_plugin (base class) does current_site.plugins.first_or_create before authorization. The plugin
# re-orders so authorize_plugin runs first, so an authenticated but unauthorized user cannot seed a
# plugins row for a site merely by requesting the URL.
RSpec.describe 'authorization runs before init_plugin side effects' do
  init_site

  # The plugin is deliberately NOT installed for this site.
  before { store_current_site(@site) }

  it 'creates no plugins row for an unauthorized user hitting the endpoint' do
    sign_in_as(user_with_manager_grants({}, 'nobody'), site: @site)

    expect do
      get '/admin/plugins/camaleon_editor/grid_editor'
    end.not_to(change { @site.plugins.where(slug: 'camaleon_editor').count })

    expect(response.location).to include('/admin/dashboard')
    expect(flash[:error]).to be_present
  end
end
