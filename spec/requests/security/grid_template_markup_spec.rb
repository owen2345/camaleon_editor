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
      'YouTube Video' => '<iframe width="100%" src="https://www.youtube.com/embed/abc" frameborder="0" ' \
                         'allowfullscreen></iframe>',
      'Audio' => '<audio width="100%" controls src="/a.mp3"></audio>'
    }.each do |block, markup|
      it "stores a template holding the editor's own #{block} block" do
        create_template(grid_with_block(markup))

        expect(@site.grid_templates.find_by(name: 'Submitted')&.description).to eq(grid_with_block(markup))
      end
    end

    # What Templates > Settings and a block's Style Settings write, as the browser serializes it into
    # the style attribute: a grid styled with the editor's own panel must save as a template.
    it "stores a template styled with the editor's own Style Settings, background image included" do
      style = 'background-image: url(&quot;/media/1/bg.jpg&quot;); background-position: center center; ' \
              'background-repeat: no-repeat; background-size: cover; background-attachment: fixed; ' \
              'background-color: rgb(255, 0, 0); border-style: solid; border-width: 2px; margin-top: 5px;'
      data_style = '{&quot;b-img&quot;:&quot;/media/1/bg.jpg&quot;}'
      markup = grid_body_markup(grid_column_markup(grid_block_markup('<p>hello</p>')),
                                attributes: %(style="#{style}" data-style="#{data_style}"))

      create_template(markup)

      expect(@site.grid_templates.find_by(name: 'Submitted')&.description).to eq(markup)
    end

    # Only the declarations the panel writes are taken out of the scan: a url that runs script, a
    # value the panel could not have written, or anything else beside them, is still refused.
    it 'still refuses a style the Style Settings panel could not have written' do
      ['style="background-image: url(&quot;javascript:alert(1)&quot;);"',
       'style="background-image: url(&quot;/a.jpg&quot;), url(&quot;/b.jpg&quot;);"',
       'style="background-repeat: no-repeat; behavior: url(/x.htc);"',
       'style="background-size: cover;" onclick="alert(1)"'].each do |attributes|
        expect { create_template(grid_body_markup(attributes: attributes)) }
          .not_to(change { @site.grid_templates.count })
      end
    end

    it 'refuses a media element whose url runs script' do
      expect { create_template(grid_with_block('<video controls><source src="javascript:alert(1)"></video>')) }
        .not_to(change { @site.grid_templates.count })
    end

    it 'refuses a frame whose url runs script, or that carries its own document' do
      ['<iframe src="javascript:alert(1)"></iframe>',
       '<iframe srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;"></iframe>'].each do |frame|
        expect { create_template(grid_with_block(frame)) }.not_to(change { @site.grid_templates.count })
      end
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

  # Core's own escape hatch for post content: a role granted unfiltered HTML for a post type can
  # already save this grid as a post, so it can save it as a template.
  it 'lets a manager trusted with unfiltered HTML store an embed, verbatim' do
    trusted = user_with_manager_grants(
      { camaleon_editor: 1, camaleon_editor_templates: 1 }, 'trusted-manager',
      post_type_meta: { post_content_unfiltered_html: [@site.post_types.first.id.to_s] }
    )
    sign_in_as(trusted, site: @site)
    markup = grid_with_block('<object data="https://example.com/widget.swf"></object>')

    create_template(markup)

    expect(@site.grid_templates.find_by(name: 'Submitted')&.description).to eq(markup)
  end

  it 'lets an administrator store a template with a script, verbatim' do
    sign_in_as(cama_admin_user, site: @site)
    markup = grid_with_block('<script>widget();</script>')

    create_template(markup)

    expect(@site.grid_templates.find_by(name: 'Submitted').description).to eq(markup)
  end
end
