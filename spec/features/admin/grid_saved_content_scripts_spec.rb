# frozen_string_literal: true

# Opening a post whose content is a grid rebuilds the grid editor from that content. An embed
# block's script is content for the public page; rebuilding the grid must keep it and not run it
# in the administrator's session.
RSpec.describe 'reopening a post whose grid holds a script', :js do
  init_site

  before do
    block = '<div class="" data-kind="editor"><div class="grid_item_content grid_item_editor">' \
            '<p>embedded widget</p><script>window.__cama_widget_loaded = true;</script></div></div>'
    column = '<div class="col-md-6" data-col="6" data-col_title="50%">' \
             "<div class=\"grid_sortable_items\">#{block}</div></div>"
    grid = %(<div class="panel_grid_body row" style="background-color: rgb(255, 204, 0);">#{column}</div>)
    # Written past the model: the point is what the editor does with content already stored.
    # rubocop:disable-next Rails/SkipsModelValidations
    CamaleonCms::Post.where(id: @post.id).update_all(content: "<div>[grid_editor data='']</div>#{grid}")

    store_current_site(@site)
    plugin_install('camaleon_editor')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"
  end

  it 'rebuilds the grid with the script kept and not run' do
    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_column .drg_item')

    page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
    saved = page.evaluate_script("jQuery('.panel_grid_editor').next('textarea').val()")

    expect(saved).to include('<script>window.__cama_widget_loaded = true;</script>')
    expect(saved).to include('background-color: rgb(255, 204, 0)')
    expect(page.evaluate_script('window.__cama_widget_loaded')).to be_nil
  end
end
