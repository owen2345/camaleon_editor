# frozen_string_literal: true

# The accordion content builder stores its Bootstrap panel class on the block's `.grid_item_content`
# element. That element is a child of the `.drg_item` the grid style modal writes a JSON style object
# to under `data-style`, so the accordion must not reuse that attribute name (two incompatible
# formats on parent/child elements). It uses `data-accordion-style`, migrating any legacy `data-style`
# on save and still reading it back for accordions saved before the split.
RSpec.describe 'the accordion style attribute', :js do
  init_site

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    admin_sign_in
    post_type = CamaleonCms::Site.first.post_types.first
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new"
  end

  # Drive grid_accordion_builder with open_modal stubbed so the builder's recover step runs and the
  # returned template's select is inspectable; then invoke the captured on_submit to check the save.
  def run_accordion_builder(panel_html)
    page.evaluate_script(<<~JS)
      (function(){
        var captured = {};
        var saved = window.open_modal;
        window.open_modal = function(opts){ captured.opts = opts; };
        var panel = $(#{panel_html.to_json});
        try { window.grid_accordion_builder(panel, $('<div></div>')); } catch(e){ captured.error = String(e); }
        var selectVal = captured.opts && $(captured.opts.content).find('.style-accordion').val();
        // set a new style and submit to exercise the migration write
        if (captured.opts) {
          $(captured.opts.content).find('.style-accordion').val('success');
          try { captured.opts.on_submit && captured.opts.on_submit($('<div></div>')); } catch(e){}
        }
        window.open_modal = saved;
        return {
          recovered: selectVal,
          hasNewAttr: panel.attr('data-accordion-style') || null,
          hasLegacyAttr: panel.attr('data-style') || null
        };
      })()
    JS
  end

  it 'restores the style from the legacy data-style, then migrates it on save' do
    result = run_accordion_builder('<div class="grid_item_content" data-style="primary"></div>')

    # legacy value restored into the select on recover
    expect(result['recovered']).to eq('primary')
    # save writes the accordion's own attribute and drops the shared data-style
    expect(result['hasNewAttr']).to eq('success')
    expect(result['hasLegacyAttr']).to be_nil
  end

  it 'restores the style from data-accordion-style when present' do
    result = run_accordion_builder(
      '<div class="grid_item_content" data-accordion-style="danger"></div>'
    )

    expect(result['recovered']).to eq('danger')
  end
end
