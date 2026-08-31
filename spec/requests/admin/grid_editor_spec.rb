# frozen_string_literal: true

# CRUD for grid templates through the plugin's admin endpoints
# (admin/plugins/camaleon_editor/grid_editor, served by Plugins::CamaleonEditor::AdminController).
RSpec.describe 'the grid editor admin' do
  init_site

  let(:admin) { cama_admin_user }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    sign_in_as(admin, site: @site)
  end

  it 'refuses the endpoints while the plugin is inactive' do
    plugin_uninstall('camaleon_editor')

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect(response).to have_http_status(:redirect)
  end

  it 'lists the grid templates of the current site' do
    @site.grid_templates.create!(name: 'Two columns', slug: 'two-cols', description: '<div>x</div>')

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Two columns')
  end

  it 'serves the new-template form' do
    get '/admin/plugins/camaleon_editor/grid_editor/new'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('grid_template_form')
  end

  it 'creates a grid template (slug minted server-side)' do
    post '/admin/plugins/camaleon_editor/grid_editor',
         params: { grid_template: { name: 'Hero', description: '<div>[grid_editor]</div>' } }

    expect(response).to have_http_status(:ok)
    template = @site.grid_templates.find_by(name: 'Hero')
    expect(template).to be_present
    expect(template.slug).to be_present
  end

  it 'updates a grid template' do
    template = @site.grid_templates.create!(name: 'Old name', slug: 'old', description: '<div>x</div>')

    patch "/admin/plugins/camaleon_editor/grid_editor/#{template.id}",
          params: { grid_template: { name: 'New name', description: '<div>z</div>' } }

    expect(response).to have_http_status(:ok)
    expect(template.reload.name).to eq('New name')
  end

  it 'serves a template value (its description) for the editor to insert' do
    template = @site.grid_templates.create!(name: 'Value', slug: 'value', description: '<div>template value</div>')

    get "/admin/plugins/camaleon_editor/grid_editor/#{template.id}"

    expect(response.body).to eq('<div>template value</div>')
  end

  # The value is returned verbatim, never evaluated as an ERB template (which would be server-side
  # Ruby execution for anyone who can author a template, or any path that seeds a term_taxonomy row).
  it 'returns a description containing ERB tags verbatim, unevaluated' do
    template = @site.grid_templates.create!(name: 'Payload', slug: 'payload',
                                            description: '<div><%= 7 * 6 %></div>')

    get "/admin/plugins/camaleon_editor/grid_editor/#{template.id}"

    expect(response.body).to eq('<div><%= 7 * 6 %></div>')
  end

  it 'destroys a grid template' do
    template = @site.grid_templates.create!(name: 'Doomed', slug: 'doomed', description: '<div>x</div>')

    delete "/admin/plugins/camaleon_editor/grid_editor/#{template.id}"

    expect(response).to have_http_status(:ok)
    expect(@site.grid_templates.where(id: template.id)).not_to exist
  end

  it 'serves the style-settings panel' do
    get '/admin/plugins/camaleon_editor/style-settings'

    expect(response).to have_http_status(:ok)
  end
end
