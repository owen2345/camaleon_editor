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

    # The markup the editor's own block builders write: a template built from stock blocks must save.
    {
      'Tabs' => '<ul class="nav nav-tabs" role="tablist"><li role="presentation" class="active">' \
                '<a href="#t0" aria-controls="home" role="tab" data-toggle="tab">One</a></li></ul>' \
                '<div class="tab-content"> <div role="tabpanel" class="tab-pane active" id="t0">x</div> </div>',
      'Slider' => '<div class="carousel-inner" role="listbox"> <div class="item active"><img src="/a.png" alt=""> ' \
                  '</div> </div><a class="left carousel-control" href="#c" role="button" data-slide="prev">' \
                  '<span class="glyphicon glyphicon-chevron-left" aria-hidden="true"></span></a>',
      'Video' => '<video width="100%" controls><source src="/v.mp4" type="video/mp4"></video>',
      'Audio' => '<audio width="100%" controls src="/a.mp3"></audio>'
    }.each do |block, markup|
      it "stores a template holding the editor's own #{block} block" do
        create_template(grid_with_block(markup))

        expect(@site.grid_templates.find_by(name: 'Submitted')&.description).to eq(grid_with_block(markup))
      end
    end

    it 'refuses a media element whose url runs script' do
      expect { create_template(grid_with_block('<video controls><source src="javascript:alert(1)"></video>')) }
        .not_to(change { @site.grid_templates.count })
    end

    it 'refuses an embedded frame' do
      expect { create_template(grid_with_block('<iframe src="https://www.youtube.com/embed/abc"></iframe>')) }
        .not_to(change { @site.grid_templates.count })
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
