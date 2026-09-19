# frozen_string_literal: true

# A grid template is markup the editor puts into the page of whoever applies it, administrators
# included. A template manager who is not an administrator is an untrusted author of that markup:
# what they may not write is refused at save - never rewritten - exactly as post content is.
RSpec.describe 'Security: grid template markup from a non-admin manager' do
  init_site

  let(:path) { '/admin/plugins/camaleon_editor/grid_editor' }
  let(:grid) do
    grid_body_markup(grid_column_markup(grid_block_markup('<p>hello</p>')), attributes: 'style="color: red;"')
  end

  def manager
    user_with_manager_grants({ camaleon_editor: 1, camaleon_editor_templates: 1 }, 'template-manager')
  end

  def create_template(description)
    post path, params: { grid_template: { name: 'Submitted', description: description } }
  end

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
  end

  context 'when signed in as the manager' do
    before { sign_in_as(manager, site: @site) }

    it 'stores ordinary grid markup exactly as submitted' do
      create_template(grid)

      expect(@site.grid_templates.find_by(name: 'Submitted').description).to eq(grid)
    end

    it 'refuses an inline event handler and stores nothing' do
      expect { create_template(grid_with_block('<img src="x" onerror="alert(1)">')) }
        .not_to(change { @site.grid_templates.count })
      expect(response.body).to include('grid_template_form', 'not allowed for your role')
    end

    it 'refuses a script element' do
      expect { create_template(grid_with_block('<script>alert(1)</script>')) }
        .not_to(change { @site.grid_templates.count })
    end

    it 'refuses the same markup on an update and keeps the stored template' do
      template = @site.grid_templates.create!(name: 'Kept', slug: 'kept', description: grid)

      patch "#{path}/#{template.id}", params: { grid_template: { description: grid_with_block('<svg onload="x()">') } }

      expect(template.reload.description).to eq(grid)
    end
  end

  it 'lets an administrator store a template with a script, verbatim' do
    sign_in_as(cama_admin_user, site: @site)
    markup = grid_with_block('<script>widget();</script>')

    create_template(markup)

    expect(@site.grid_templates.find_by(name: 'Submitted').description).to eq(markup)
  end
end
