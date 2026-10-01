# frozen_string_literal: true

# The post's field has two writers: the grid editor, and the text editor it stands in front of.
# Core has the text editor write its content into the field when it loses focus, with every draft
# and as the form is sent, and the text editor's serialization of a grid is not the grid's export:
# <b> and rgb() are respelled, a newline goes between tags. While the grid editor is the one shown,
# the text editor answers with the grid's export, so the export is what the post stores.
RSpec.describe 'saving a post from the grid editor', :js do
  init_site

  let(:script) { '<script>window.__cama_widget_loaded = true;</script>' }
  let(:stored_content) do
    block = grid_block_markup("<p>embedded widget</p>#{script}<p><b>bold</b></p>", kind: 'editor')
    grid = grid_body_markup(grid_column_markup(block), attributes: 'style="background-color: rgb(255, 204, 0);"')
    grid_post_content(grid)
  end

  def post_content
    CamaleonCms::Post.find(@post.id).content
  end

  def open_stored_post(as: nil)
    store_post_content(@post, stored_content)
    install_plugin_and_open_post_editor(as: as, post: @post)
    find('.panel_grid_editor .panel_grid_body .drg_column .drg_item')
  end

  def leave_for_the_text_editor
    accept_confirm { find('.grid_editor_menu .toggle_panel_grid').click }
    find('.mce-tinymce')
  end

  def text_editor_holds(markup)
    page.execute_script(<<~JS, markup)
      tinymce.get(jQuery('#form-post textarea.tinymce_textarea').first().attr('id')).setContent(arguments[0]);
    JS
  end

  def change_in_the_text_editor(from, to)
    text_editor_holds(text_editor_content.sub(from) { to })
  end

  context 'with an administrator' do
    before { open_stored_post }

    it 'stores the grid as the grid exported it, a block script included' do
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to include(script, '<b>bold</b>', 'background-color: rgb(255, 204, 0)')
      expect(post_content).to eq(export)
    end

    it 'stores a post saved with nothing changed as it was' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    # The post form writes each text editor's content into its field to tell whether there is
    # anything to save, two seconds after it opens and with every draft; so does a text editor
    # that loses focus.
    def let_core_read_the_text_editors
      page.execute_script(<<~JS)
        jQuery.each(tinymce.editors, function(_index, editor){
          jQuery('#' + editor.id).val(editor.getContent()).trigger('change');
          editor.fire('blur');
        });
      JS
    end

    it 'keeps the export in the field when core reads the text editors' do
      trigger_grid_auto_save
      let_core_read_the_text_editors

      expect(page.evaluate_script("jQuery('.panel_grid_editor').next('textarea')[0].value")).to eq(saved_grid_content)
    end

    # A block form loads a text editor of its own through jQuery's tinymce(), and from then on
    # val() hands the grid's export to the post's text editor and leaves the field alone.
    it 'stores the export once a block form has loaded a text editor of its own' do
      page.execute_script(<<~JS)
        jQuery('<textarea></textarea>').appendTo('body').tinymce(cama_get_tinymce_settings({height: '120px'}));
        jQuery('.panel_grid_body .drg_item b').text('changed');
      JS
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to include(script, '<b>changed</b>')
      expect(post_content).to eq(export)
    end

    it 'saves the export as the draft' do
      trigger_grid_auto_save
      let_core_read_the_text_editors
      page.execute_script('App_post.save_draft_ajax(function(){});')
      wait_for_ajax

      draft = CamaleonCms::Post.drafts.find_by!(post_parent: @post.id)
      expect(draft.content).to eq(saved_grid_content)
    end

    # Back in the text editor, the author sees and edits the text editor's content: that is what
    # is stored, in the text editor's serialization, with the grid's scripts still in it.
    it 'leaves the save to the text editor once the author went back to it' do
      trigger_grid_auto_save
      leave_for_the_text_editor
      shown = text_editor_content
      submit_post_form

      expect(shown).to include('<strong>bold</strong>', script)
      expect(post_content.delete("\r\n")).to eq(shown)
    end

    # The grid shown again is the grid of what the text editor holds: as it was left when nothing
    # was changed there, made again from the text editor's content when something was.
    context 'when the author comes back to the grid from the text editor' do
      before { leave_for_the_text_editor }

      it 'stores the post as it was when nothing was changed in the text editor' do
        open_grid_editor
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      it 'makes the grid again from what was changed in the text editor, and stores that' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        changed = text_editor_content
        open_grid_editor

        expect(page).to have_css('.panel_grid_body .drg_item strong', text: 'changed in the text editor', visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item', count: 1)
        expect(page.evaluate_script('window.__cama_widget_loaded')).to be_nil

        submit_post_form

        expect(changed).to include(script)
        expect(post_content.delete("\r\n")).to eq(changed)
      end

      it 'stores the export of the grid made again once that grid changes' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        open_grid_editor
        find('.panel_grid_body .drg_item strong', text: 'changed in the text editor', visible: :all)
        trigger_grid_auto_save
        export = saved_grid_content
        submit_post_form

        expect(export).to include(script, '<strong>changed in the text editor</strong>')
        expect(post_content.delete("\r")).to eq(export)
      end

      it 'keeps the author in the text editor when what was changed there is no longer a grid alone' do
        text_editor_holds("#{text_editor_content}<p>written after the grid</p>")
        changed = text_editor_content
        open_grid_editor

        expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
        expect(page).to have_css('.mce-tinymce')
        expect(page).to have_no_css('.panel_grid_editor')

        page.execute_script("jQuery('#cama_alert_modal').modal('hide');")
        expect(page).to have_no_css('#cama_alert_modal')
        submit_post_form

        expect(post_content.delete("\r\n")).to eq(changed)
      end

      # Making the grid again runs the parsers that rebuild a saved grid, and a widget they set up
      # can throw: the grid built earlier comes back whole, and the author stays in the text editor.
      it 'keeps the grid built earlier when making it again throws' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        page.execute_script("jQuery.fn.sortable = function(){ throw new Error('widget broke'); };")
        open_grid_editor

        expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
        expect(page).to have_css('.mce-tinymce')
        expect(page).to have_no_css('.panel_grid_editor')
        expect(page).to have_css('.panel_grid_body[style*="background-color"] .drg_item > .header_box',
                                 count: 1, visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item b', text: 'bold', visible: :all)
      end

      # Other content written in the text editor is no grid to make. The grid built earlier comes
      # back as it was left, standing for what it stood for: what the grid shows is what is saved.
      it 'stores the grid, not other content written in the text editor meanwhile' do
        text_editor_holds('<p>written instead of the grid</p>')
        open_grid_editor
        find('.panel_grid_body .drg_item')
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      # That content is kept for the text editor, whatever the grid hands it meanwhile: going back
      # there brings it back, and there it is what is saved.
      it 'brings other content written in the text editor back there, where it is what is saved' do
        text_editor_holds('<p>written instead of the grid</p>')
        open_grid_editor
        find('.panel_grid_body .drg_item')
        trigger_grid_auto_save
        leave_for_the_text_editor
        shown = text_editor_content
        submit_post_form

        expect(shown).to eq('<p>written instead of the grid</p>')
        expect(post_content).to eq(shown)
      end
    end
  end

  # A grid opened over other content has exported nothing yet: the text editor's content stays what
  # the post stores until the grid's first change.
  context 'with a grid opened over other content' do
    let(:stored_content) { '<p>written in the text editor</p>' }

    before do
      store_post_content(@post, stored_content)
      install_plugin_and_open_post_editor(post: @post)
      open_grid_editor
      find('.panel_grid_editor .panel_grid_body', visible: :all)
    end

    it 'stores the content of the text editor while the grid has exported nothing' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    it 'stores the export from the first change of the grid on' do
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to start_with(grid_post_content('<div class="panel_grid_body row'))
      expect(post_content).to eq(export)
    end

    # A detour through the text editor changes nothing about that: the grid has still exported
    # nothing, and what was written in the text editor meanwhile is what the post stores.
    it 'stores what was written in the text editor meanwhile while the grid has exported nothing' do
      leave_for_the_text_editor
      text_editor_holds('<p>written meanwhile</p>')
      open_grid_editor
      find('.panel_grid_editor .grid_editor_menu')
      submit_post_form

      expect(post_content).to eq('<p>written meanwhile</p>')
    end
  end

  # A post in several languages has one field for each, with a text editor and a grid editor of
  # its own, and core composes what the post stores from them.
  context 'with a post in two languages' do
    let(:stored_content) { "<!--:en-->#{grid_in('english')}<!--:--><!--:es-->#{grid_in('spanish')}<!--:-->" }

    def grid_in(language)
      grid_post_content(grid_with_block("<p>#{language}</p>#{script}<p><b>bold</b></p>", kind: 'editor'))
    end

    before do
      @site.set_meta('languages_site', %w[en es])
      store_post_content(@post, stored_content)
      install_plugin_and_open_post_editor(post: @post)
      page.assert_selector('.panel_grid_editor .panel_grid_body .drg_item', count: 2, visible: :all)
    end

    it 'stores a post saved with nothing changed as it was' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    it 'stores the export of the changed language, and the other language as it was' do
      page.execute_script(<<~JS)
        var english = jQuery('.panel_grid_editor').first();
        english.find('.panel_grid_body .drg_item b').text('changed');
        english.trigger('auto_save');
      JS
      export = saved_grid_content
      submit_post_form

      expect(export).to include('<p>english</p>', script, '<b>changed</b>')
      expect(post_content).to eq("<!--:en-->#{export}<!--:--><!--:es-->#{grid_in('spanish')}<!--:-->")
    end
  end

  # Core refuses a script from a role it does not trust with unfiltered HTML, and rewrites nothing.
  # The text editor used to take the script out on the way, so the save went through without it.
  context 'with an author core does not trust with unfiltered HTML' do
    # The grid's marker is a shortcode, so saving a grid takes core's shortcode permission as well.
    before do
      post_type = [@post.post_type.id.to_s]
      grants = { Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1, content_shortcodes: 1 }
      author = user_with_manager_grants(grants, 'grid-author',
                                        post_type_meta: { edit: post_type, edit_other: post_type,
                                                          edit_publish: post_type })
      open_stored_post(as: author)
    end

    it 'refuses a changed grid that holds a script, and leaves the post as it was' do
      page.execute_script("jQuery('.panel_grid_body .drg_item b').text('changed');")
      trigger_grid_auto_save
      submit_post_form

      expect(page).to have_css('.alert-danger', text: /script/i)
      expect(post_content).to eq(stored_content)
    end

    it 'stores a changed grid once the script is out of it' do
      page.execute_script(<<~JS)
        jQuery('.panel_grid_body .drg_item script').remove();
        jQuery('.panel_grid_body .drg_item b').text('changed');
      JS
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to include('<b>changed</b>')
      expect(export).not_to include('<script')
      expect(post_content).to eq(export)
    end

    # The text editor's version of a grid is changed content to core, and still holds the script.
    it 'refuses the text editor version of a grid that holds a script, and leaves the post as it was' do
      leave_for_the_text_editor
      submit_post_form

      expect(page).to have_css('.alert-danger', text: /script/i)
      expect(post_content).to eq(stored_content)
    end
  end
end
