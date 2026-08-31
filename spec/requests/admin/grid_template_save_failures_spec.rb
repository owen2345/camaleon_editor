# frozen_string_literal: true

# create/update must surface a refused save instead of answering 200 with the template silently gone:
# ActiveRecord::Relation#create returns the record whether or not it validated, so the endpoints check
# #save/#update and re-render the form (with its errors) on failure.
RSpec.describe 'grid-template save failures are surfaced' do
  include ActiveSupport::Testing::TimeHelpers

  init_site

  let(:admin) { CamaManager.get_user_class_name.constantize.find_by!(username: 'admin') }
  let(:path) { '/admin/plugins/camaleon_editor/grid_editor' }

  # A non-admin whose role holds the editor grants but NOT content_shortcodes, so the content-shortcode
  # gate on the template description refuses a registered shortcode. Both editor keys are granted so the
  # example survives the later split of the permission into use vs manage-templates.
  def editor_user
    role = @site.user_roles.create!(name: 'grid-editor-user', slug: 'grid-editor-user')
    role.set_meta("_manager_#{@site.id}", { camaleon_editor: 1, camaleon_editor_templates: 1 })
    create(:user, role: 'grid-editor-user', site: @site)
  end

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
  end

  it 'persists two templates created within the same second' do
    sign_in_as(admin, site: @site)

    freeze_time do
      post path, params: { grid_template: { name: 'First', description: '<div>1</div>' } }
      post path, params: { grid_template: { name: 'Second', description: '<div>2</div>' } }
    end

    expect(@site.grid_templates.pluck(:name)).to include('First', 'Second')
  end

  it 're-renders the form with errors when the save is refused, and stores nothing' do
    sign_in_as(editor_user, site: @site)

    expect do
      post path, params: { grid_template: { name: 'Blocked', description: '<div>[widget id=1]</div>' } }
    end.not_to change { @site.grid_templates.count }

    expect(response.body).to include('grid_template_form')
    expect(response.body).to include('error_explanation')
  end

  it 'surfaces an update failure the same way' do
    template = @site.grid_templates.create!(name: 'Keep', slug: 'keep', description: '<div>ok</div>')
    sign_in_as(editor_user, site: @site)

    patch "#{path}/#{template.id}", params: { grid_template: { description: '<div>[widget id=1]</div>' } }

    expect(template.reload.description).to eq('<div>ok</div>')
    expect(response.body).to include('error_explanation')
  end
end
