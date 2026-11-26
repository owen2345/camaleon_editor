# frozen_string_literal: true

# A page can remove the text editor of a field and set up a new one while the grid editor of the
# field stays. Camaleon does this for the text editors of a custom field group that the author
# sorts. The grid editor then works with the new text editor. A read of that editor returns the
# export, a grid change goes to it, and the Text Editor link shows its panel.
RSpec.describe 'a text editor made again for a field that has its grid editor', :js do
  init_site

  let(:stored_content) { grid_post_content(grid_with_block('<p><b>bold</b></p>', kind: 'editor')) }

  # The text editor writes <strong> for <b>, and a newline between tags.
  def as_the_text_editor_writes(content)
    content.gsub('<b>', '<strong>').gsub('</b>', '</strong>')
  end

  # Removes the post's text editor and sets up a new one for the same field, and waits until the
  # new editor is ready. `settings` is the script of the editor settings. `selector` in that script
  # finds the field. With `field`, the field gets that value before the new editor reads it.
  def make_the_text_editor_again(settings, field: nil)
    page.execute_script(<<~JS, field)
      var field = #{POST_TEXT_EDITOR_FIELD};
      var selector = '#' + field.attr('id');
      window.__cama_first_text_editor = tinymce.get(field.attr('id'));
      window.__cama_first_text_editor.remove();
      if(arguments[0] !== null) field[0].value = arguments[0];
      tinymce.init(#{settings});
    JS
    wait_until do
      page.evaluate_script(<<~JS)
        (function(){
          var editor = #{POST_TEXT_EDITOR};
          return !!editor && editor !== window.__cama_first_text_editor && !!editor.initialized;
        })()
      JS
    end
  end

  def text_editor_panel_shown
    page.evaluate_script("jQuery(#{POST_TEXT_EDITOR}.editorContainer).is(':visible')")
  end

  # Only a text editor with the settings of Camaleon has the Grid Editor button. The button calls
  # this function too.
  def go_back_to_the_grid_editor
    page.execute_script("#{POST_TEXT_EDITOR_FIELD}.gridEditor(#{POST_TEXT_EDITOR});")
  end

  def open_stored_post
    store_post_content(@post, stored_content)
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_item')
  end

  {
    'the settings of Camaleon' => 'cama_get_tinymce_settings({selector: selector})',
    'the settings of a page' => '{selector: selector}'
  }.each do |name, settings|
    context "with #{name}" do
      context 'when the grid editor is visible' do
        before { open_stored_post }

        it 'keeps the new text editor hidden, and builds no second grid editor' do
          make_the_text_editor_again(settings)

          expect(page).to have_css('.panel_grid_editor', count: 1)
          expect(text_editor_panel_shown).to be(false)
        end

        it 'returns the export for a read of the new text editor' do
          trigger_grid_auto_save
          export = saved_grid_content
          make_the_text_editor_again(settings)

          expect(export).to include('<b>bold</b>')
          expect(page.evaluate_script("#{POST_TEXT_EDITOR}.getContent()")).to eq(export)
        end

        it 'stores a grid change that the author makes afterwards' do
          make_the_text_editor_again(settings)
          change_the_grid
          export = saved_grid_content
          submit_post_form

          expect(export).to include('<b>changed</b>')
          expect(post_content).to eq(export)
        end

        # A post that opened as a grid has no backup for the text editor. The text editor then
        # shows the export, which the new editor got when the grid editor took it.
        it 'gives the export to the new text editor, whatever the field holds' do
          make_the_text_editor_again(settings, field: '<p>not the export</p>')
          leave_for_the_text_editor

          expect(text_editor_content).to eq(as_the_text_editor_writes(stored_content))
        end

        it 'shows the new text editor when the author leaves the grid editor' do
          make_the_text_editor_again(settings)
          leave_for_the_text_editor

          expect(page).to have_no_css('.panel_grid_editor')
          expect(text_editor_panel_shown).to be(true)
        end
      end

      context 'when the author is in the text editor' do
        before do
          open_stored_post
          leave_for_the_text_editor
        end

        # The field then holds grid content. The author still stays in the text editor.
        it 'leaves the author in the new text editor' do
          make_the_text_editor_again(settings)

          expect(page).to have_no_css('.panel_grid_editor')
          expect(text_editor_panel_shown).to be(true)
        end

        it 'keeps the grid and the post as they were when the author goes back with no change' do
          make_the_text_editor_again(settings)
          go_back_to_the_grid_editor

          expect(page).to have_css('.panel_grid_editor .drg_item b', text: 'bold', visible: :all)
          expect(text_editor_panel_shown).to be(false)
          submit_post_form
          expect(post_content).to eq(stored_content)
        end

        it 'builds the grid from a change that the author makes in the new text editor' do
          make_the_text_editor_again(settings)
          text_editor_holds(text_editor_content.sub('bold', 'changed in the text editor'))
          go_back_to_the_grid_editor

          expect(page).to have_css('.panel_grid_editor .drg_item', text: 'changed in the text editor', visible: :all)
          submit_post_form
          expect(post_content).to include('changed in the text editor')
        end

        it 'builds the grid from a change that the author made before the new text editor' do
          text_editor_holds(text_editor_content.sub('bold', 'changed in the text editor'))
          make_the_text_editor_again(settings)
          go_back_to_the_grid_editor

          expect(page).to have_css('.panel_grid_editor .drg_item', text: 'changed in the text editor', visible: :all)
        end
      end

      # A grid editor opened on other content has no export until its first change. A save then
      # stores the content of the text editor.
      context 'when the grid has no export' do
        before do
          store_post_content(@post, '<p>written <strong>before</strong> the grid</p>')
          open_post_in_editor(@post)
          open_grid_editor
          find('.panel_grid_editor')
        end

        it 'keeps the new text editor hidden, and a save stores its content' do
          make_the_text_editor_again(settings)

          expect(page).to have_css('.panel_grid_editor')
          expect(text_editor_panel_shown).to be(false)
          submit_post_form
          expect(post_content.delete("\n")).to eq('<p>written <strong>before</strong> the grid</p>')
        end
      end

      # A page can put its own element between the panel of the text editor and the field.
      context 'with an element between the panel of the text editor and the field' do
        before do
          open_stored_post
          page.execute_script("#{POST_TEXT_EDITOR_FIELD}.before('<span class=\"cama_between\"></span>');")
        end

        it 'keeps the new text editor hidden, and builds no second grid editor' do
          make_the_text_editor_again(settings)

          expect(page).to have_css('.panel_grid_editor', count: 1)
          expect(text_editor_panel_shown).to be(false)
        end
      end

      # The grid editor of a field that has no text editor of its own can work with the text editor
      # of another field.
      context 'with grid editors on fields that work with the text editor of the post' do
        before do
          open_post_in_editor(@post)
          page.execute_script(<<~JS)
            jQuery('<div id="cama_two_fields"><textarea></textarea><textarea></textarea></div>').appendTo('#form-post');
            jQuery('#cama_two_fields textarea').gridEditor(#{POST_TEXT_EDITOR});
          JS
          first('#cama_two_fields .panel_grid_editor')
        end

        it 'gives a later grid change to the new text editor' do
          make_the_text_editor_again(settings)
          page.execute_script("jQuery('#cama_two_fields .panel_grid_editor').first().trigger('auto_save');")

          expect(page.evaluate_script("#{POST_TEXT_EDITOR}.getContent({format: 'raw'})")).to include('[grid_editor')
        end

        # A grid editor takes only the text editor that replaces the removed one, by its id.
        it 'does not take the new text editor of another field' do
          page.execute_script("#{POST_TEXT_EDITOR}.remove();")
          set_up_text_editors(['cama_other_field'], settings)
          panel_shown = page.evaluate_script("jQuery(tinymce.get('cama_other_field').editorContainer).is(':visible')")

          expect(panel_shown).to be(true)
        end
      end
    end
  end
end
