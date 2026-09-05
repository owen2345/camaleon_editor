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

  it 'serves the style-settings panel with a unique name per field' do
    get '/admin/plugins/camaleon_editor/style-settings'

    expect(response).to have_http_status(:ok)

    # The style save serialises the form by field name, last-wins and silently: two fields
    # sharing a name destroy one of them (the border colour/width inputs once shipped that way).
    doc = Nokogiri::HTML(response.body)
    names = doc.css('input[name], select[name]').pluck('name')
    expect(names).to eq(names.uniq)
    expect(doc.at_css('input.color_border')['name']).to eq('bo-c')
    expect(doc.at_css('input.border_width')['name']).to eq('bo-w')
  end

  it 'serves the background image input as free text' do
    get '/admin/plugins/camaleon_editor/style-settings'

    # The upload picker writes site-relative paths ("/media/..."), which type=url would mark
    # invalid the moment native validation ever runs on this form.
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('input.bg_image')['type']).to eq('text')
  end

  it 'lets every style panel select fall back to the default' do
    get '/admin/plugins/camaleon_editor/style-settings'

    # The save skips empty values, so a select whose first option carries a value force-writes
    # that CSS property on every save, overriding whatever the theme set.
    doc = Nokogiri::HTML(response.body)
    doc.css('select').each do |select|
      expect(select.at_css('option')['value']).to eq(''), "select #{select['name']} forces its first option"
    end
  end

  it 'associates every label in the style panel with a field' do
    get '/admin/plugins/camaleon_editor/style-settings'

    doc = Nokogiri::HTML(response.body)
    field_ids = doc.css('input[id], select[id]').pluck('id')
    labels = doc.css('label')
    expect(labels).not_to be_empty
    labels.each do |label|
      expect(field_ids).to include(label['for']), "label #{label.text.inspect} points at no field"
    end
  end
end
