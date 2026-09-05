# frozen_string_literal: true

# The Style Settings partial powers the grid editor's per-block style modal. Its border Color and
# border Width inputs must not share a `name`: the modal serialises the form into the block's
# data-style by field name, so a shared name makes the width overwrite the colour (colour is lost)
# and, on reopen, feeds that non-colour value into the colour field's colorpicker — which crashes and
# the modal never opens.
RSpec.describe 'the grid editor style-settings partial' do
  init_site

  let(:admin) { cama_admin_user }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    sign_in_as(admin, site: @site)
  end

  it 'gives the border colour and width inputs distinct names' do
    get '/admin/plugins/camaleon_editor/style-settings'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('color_border" name="bo-c"')
    expect(response.body).to include('border_width" name="bo-w"')
    # the width input must no longer reuse the colour field's name
    expect(response.body).not_to include('border_width" name="bo-c"')
  end
end
