# frozen_string_literal: true

# While the author drags a custom field group, Camaleon removes the text editors of the group, and
# it sets them up again at the drop. Camaleon 2.9.4 takes the element after the panel of a text
# editor for the field of that editor. For this reason, the grid editor is before the panel of the
# text editor, and the field stays immediately after the panel.
RSpec.describe 'a grid editor in a custom field group that the author sorts', :js do
  init_site

  let(:stored_grid) { grid_post_content(grid_with_block('<p><b>bold</b></p>', kind: 'editor')) }

  # The script of the field that has the grid editor, and the script of its text editor.
  let(:grid_field) { "jQuery('.custom_sortable_grouped .panel_grid_editor').nextAll('textarea').first()" }
  let(:grid_field_editor) { "tinymce.get(#{grid_field}.attr('id'))" }

  def field_ids
    page.evaluate_script(<<~JS)
      jQuery('.custom_sortable_grouped textarea.input-value').map(function(){ return this.id; }).get()
    JS
  end

  def text_editor_ids
    page.evaluate_script('jQuery.map(tinymce.editors, function(editor){ return editor.id; })')
  end

  # Gives the text editor of the first group the stored grid and builds the grid editor from it, as
  # the Grid Editor button does. The page keeps that text editor, to tell a new one from it.
  def build_a_grid_in_the_first_group
    page.execute_script(<<~JS, field_ids.first, stored_grid)
      var editor = window.__cama_first_field_editor = tinymce.get(arguments[0]);
      editor.setContent(arguments[1]);
      editor.save();
      jQuery(editor.targetElm).gridEditor(editor);
    JS
    find('.custom_sortable_grouped .panel_grid_editor .drg_item')
  end

  # Drags the first group by its handle onto the second one, slowly enough to start a sort, and
  # waits until each text editor of the page is ready again.
  def drag_the_first_group
    page.execute_script("jQuery(document).on('sortstop', function(){ window.__cama_sort_stopped = true; });")
    drag = hold_the_first_group.move_by(0, 30).pause(duration: 0.2)
    drag.move_to(all('.custom_sortable_grouped').last.native).pause(duration: 0.2)
    drag.move_by(0, 15).pause(duration: 0.3).release.perform
    wait_for_the_text_editors_after_the_sort
  end

  # Holds the first group by its handle until jQuery UI reads the hold as a drag.
  def hold_the_first_group
    handle = first('.custom_sortable_grouped .header-field-grouped .move').native
    page.execute_script('arguments[0].scrollIntoView({block: "center"});', handle)
    page.driver.browser.action.click_and_hold(handle).pause(duration: 0.4)
  end

  def wait_for_the_text_editors_after_the_sort
    wait_until do
      page.evaluate_script(<<~JS)
        !!window.__cama_sort_stopped && jQuery.grep(tinymce.editors, function(editor){
          return !editor.initialized;
        }).length === 0
      JS
    end
  end

  before do
    post_type = @site.post_types.find_by(slug: 'post')
    group = @site.custom_field_groups.create!(name: 'Sections', slug: 'sections', is_repeat: true,
                                              object_class: 'PostType_Post', objectid: post_type.id)
    group.add_manual_field({ 'name' => 'Body', 'slug' => 'section_body' }, { 'field_key' => 'editor' })
    install_plugin_and_open_post_editor
    find('.duplicate_cutom_group').click
    wait_until { field_ids.size == 2 }
    field_ids.each { |id| wait_for_text_editor("tinymce.get('#{id}')") }
    build_a_grid_in_the_first_group
    watch_for_a_sort
  end

  it 'sets up the text editor of the field again, hidden, and no other text editor' do
    editors = text_editor_ids
    drag_the_first_group

    expect(sort_started).to be(true)
    expect(text_editor_ids).to match_array(editors)
    expect(page.evaluate_script("#{grid_field_editor} !== window.__cama_first_field_editor")).to be(true)
    expect(page).to have_css('.custom_sortable_grouped .panel_grid_editor', count: 1)
    expect(page.evaluate_script("jQuery(#{grid_field_editor}.editorContainer).is(':visible')")).to be(false)
  end

  it 'writes a grid change that the author makes after the sort into the field' do
    drag_the_first_group
    page.execute_script("jQuery('.panel_grid_body .drg_item strong').text('changed');")
    trigger_grid_auto_save
    export = saved_grid_content
    page.execute_script('tinymce.triggerSave();')

    expect(export).to include('<strong>changed</strong>')
    expect(page.evaluate_script("#{grid_field}[0].value")).to eq(export)
  end
end
