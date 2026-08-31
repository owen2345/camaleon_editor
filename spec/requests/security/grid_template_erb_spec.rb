# frozen_string_literal: true

# The admin show endpoint returns a stored grid-template description for the editor to insert. It
# must return the stored bytes verbatim: rendering them as an inline ERB template would hand
# server-side Ruby execution to anyone allowed to author templates -- and to any data path that can
# seed term_taxonomy rows -- far beyond what the editor permission grants.
RSpec.describe 'Security: grid-template values are not ERB-evaluated' do
  init_site

  let(:admin) { CamaManager.get_user_class_name.constantize.find_by!(username: 'admin') }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    sign_in_as(admin, site: @site)
  end

  it 'returns a description containing ERB tags verbatim, unevaluated' do
    template = @site.grid_templates.create!(name: 'Payload', slug: 'payload',
                                            description: '<div><%= 7 * 6 %></div>')

    get "/admin/plugins/camaleon_editor/grid_editor/#{template.id}"

    expect(response.body).to eq('<div><%= 7 * 6 %></div>')
  end
end
