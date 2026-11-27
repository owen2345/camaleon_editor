# frozen_string_literal: true

# A plugin or a theme can call jQuery's tinymce() on the page. The first call with settings on a set
# that is not empty installs the jQuery plugin of TinyMCE. That plugin changes html(), text(), val(),
# append(), prepend(), remove() and empty() for the whole page. These methods then act on the text
# editor whose id an element of the set carries. remove(), replaceWith(), replaceAll() and empty()
# also remove the text editor whose panel id a descendant carries ("post_content_parent" with the
# class "mceEditor"). Stored content and templates can give a grid node any id. The grid editor uses
# DOM calls on its nodes, so the grid gets each change and the text editors stay.
RSpec.describe 'a grid node that carries the id of the post text editor', :js do
  init_site

  # The id of the post field, which is also the id of its text editor.
  let(:id) { 'post_content' }
  let(:panel_of_the_text_editor) { %(<span class="mceEditor" id="#{id}_parent"></span>) }

  # Stores `body` as the grid of the post and opens the post. Then a script of the page loads a text
  # editor through jQuery's tinymce().
  def open_the_grid(body)
    store_post_content(@post, grid_post_content(body))
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_column')
    expect(page.evaluate_script("#{POST_TEXT_EDITOR}.id")).to eq(id)
    load_a_text_editor_through_jquery
  end

  def post_text_editor_in_place?
    page.evaluate_script('!!tinymce.get(arguments[0])', id)
  end

  # A block of the kind `kind` whose own element carries `attributes`.
  def block_with(inner, attributes, kind: 'text')
    grid_block_markup(inner, kind: kind).sub('<div ', "<div #{attributes} ")
  end

  # A column whose own element carries `attributes`.
  def column_with(inner, attributes)
    grid_column_markup(inner).sub('<div ', "<div #{attributes} ")
  end

  # The value of the textarea of an item in the list of a block form, read from the textarea itself.
  def listed_item_content
    page.evaluate_script("jQuery('#ow_inline_modal textarea.descr')[0].value")
  end

  it 'keeps the text editor, and records the export, when a grid root with its id exports' do
    open_the_grid(grid_with_block('<p>kept</p>', attributes: %(id="#{id}")))
    trigger_grid_auto_save

    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).to include(%(id="#{id}"), '<p>kept</p>')
  end

  it 'keeps the text editor when a block holds an element with the id of its panel, and the grid exports' do
    open_the_grid(grid_with_block("<p>kept</p>#{panel_of_the_text_editor}"))
    trigger_grid_auto_save

    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).to include('<p>kept</p>')
  end

  it 'keeps the text editor when the author deletes a block with its id' do
    open_the_grid(grid_body_markup(grid_column_markup(block_with('<p>deleted</p>', %(id="#{id}")))))
    accept_confirm { page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_remove').click();") }
    expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)

    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).not_to include('<p>deleted</p>')
  end

  it 'keeps the text editor when the author deletes a column with its id' do
    open_the_grid(grid_body_markup(column_with(grid_block_markup('<p>deleted</p>'), %(id="#{id}"))))
    accept_confirm { page.execute_script("jQuery('.panel_grid_body .drg_column .grid_col_remove').click();") }
    expect(page).to have_no_css('.panel_grid_body .drg_column', visible: :all)

    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).not_to include('<p>deleted</p>')
  end

  # The copy of a column leaves out a block that fades out.
  it 'keeps the text editor when the author copies a column while a block with its id fades out' do
    open_the_grid(grid_body_markup(grid_column_markup(block_with('<p>deleted</p>', %(id="#{id}")))))
    confirm_every_prompt
    page.execute_script(<<~JS)
      jQuery('.panel_grid_body .drg_item .grid_content_remove').click();
      jQuery('.panel_grid_body .drg_column .grid_col_clone').first().click();
    JS
    expect(page).to have_css('.panel_grid_body .drg_column', count: 2)
    expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)

    expect(post_text_editor_in_place?).to be(true)
  end

  it 'clears a grid whose root carries the id, and keeps the text editor' do
    open_the_grid(grid_with_block('<p>cleared</p>', attributes: %(id="#{id}")))
    accept_confirm { find('.grid_editor_menu .clear').click }

    expect(page).to have_no_css('.panel_grid_body .drg_column')
    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).not_to include('<p>cleared</p>')
  end

  it 'puts back a grid whose root carries the id when a template fails, and keeps the text editor' do
    @site.grid_templates.create!(name: 'Full column', slug: 'full-column',
                                 description: grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    open_the_grid(grid_with_block('<p>kept</p>', attributes: %(id="#{id}")))
    make_the_grid_export_throw
    open_templates_list
    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_no_css('.panel_grid_body .drg_column .header_box', text: '100%')
    expect(post_text_editor_in_place?).to be(true)
  end

  it 'keeps the text editor when a template replaces a grid that holds a column with its id' do
    @site.grid_templates.create!(name: 'Full column', slug: 'full-column',
                                 description: grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    open_the_grid(grid_body_markup(column_with(grid_block_markup('<p>replaced</p>'), %(id="#{id}"))))
    open_templates_list
    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '100%')
    expect(post_text_editor_in_place?).to be(true)
    expect(saved_grid_content).not_to include('<p>replaced</p>')
  end

  # The handler of the sort start fills the placeholder from the dragged block. The example runs that
  # handler, as end_a_sort runs the handler of the sort end.
  it 'gives the placeholder of a sort the markup of a block with its id, and keeps the text editor' do
    open_the_grid(grid_body_markup(grid_column_markup(block_with('<p>moved</p>', %(id="#{id}")))))
    markup = page.evaluate_script(<<~JS)
      (function(){
        var area = #{FIRST_COLUMN_AREA}, placeholder = jQuery('<div>');
        var ui = {helper: area.children('.drg_item').first(), placeholder: placeholder};
        area.sortable('option', 'start').call(area[0], {}, ui);
        return placeholder[0].innerHTML;
      })()
    JS

    expect(markup).to include('<p>moved</p>')
    expect(markup).not_to include('[grid_editor')
    expect(post_text_editor_in_place?).to be(true)
  end

  # A grid editor whose build throws an error is removed, and the text editor shows again.
  it 'keeps the text editor when a grid that holds an element with the id of its panel cannot be built' do
    open_post_in_editor(@post)
    load_a_text_editor_through_jquery
    content = grid_post_content(grid_with_block("<p>kept</p>#{panel_of_the_text_editor}"))
    page.execute_script(<<~JS, content)
      var editor = #{POST_TEXT_EDITOR}, field = jQuery(editor.getElement());
      jQuery.fn.sortable = function(){ throw new Error('widget broke'); };
      editor.setContent(arguments[0]);
      field[0].value = arguments[0];
      field.gridEditor(editor);
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor', visible: :all)
    expect(post_text_editor_in_place?).to be(true)
  end

  context 'when the grid is built again from the text editor' do
    # The author goes to the text editor, the content there changes to `body`, and the author goes
    # back to the grid editor. The steps look in the post form: the text editor that a script loaded
    # has a panel and a Grid Editor button too.
    def build_the_grid_again(body)
      accept_confirm { find('.grid_editor_menu .toggle_panel_grid').click }
      find('#form-post .mce-tinymce')
      text_editor_holds(grid_post_content(body))
      within('#form-post') { open_grid_editor }
      find('.panel_grid_editor .panel_grid_body .drg_column')
    end

    before { open_the_grid(grid_with_block('<p>first</p>')) }

    it 'gives a column and a block with the id their headers' do
      build_the_grid_again(grid_body_markup(column_with(block_with('<p>again</p>', %(id="#{id}")), %(id="#{id}"))))

      expect(page).to have_css('.panel_grid_body .drg_column > .header_box .dropdown')
      expect(page).to have_css('.panel_grid_body .drg_item > .header_box .dropdown')
      expect(post_text_editor_in_place?).to be(true)
    end

    it 'gives a grid root with the id the value attribute of the content' do
      build_the_grid_again(grid_with_block('<p>again</p>', attributes: %(id="#{id}" value="kept")))

      expect(page).to have_css('.panel_grid_editor .panel_grid_body[value="kept"]')
    end
  end

  context 'when the author opens a block form' do
    it 'shows the content of a text block whose content element carries the id' do
      block = grid_block_markup('<p>text</p>').sub('grid_item_text"', %(grid_item_text" id="#{id}"))
      open_the_grid(grid_body_markup(grid_column_markup(block)))
      open_first_block_form
      find('#ow_inline_modal textarea')

      expect(page.evaluate_script("jQuery('#ow_inline_modal textarea')[0].value")).to eq('<p>text</p>')
    end

    it 'loads the content of an Editor block whose content element carries the id into its form' do
      block = grid_block_markup('<p>editor text</p>', kind: 'editor')
              .sub('grid_item_editor"', %(grid_item_editor" id="#{id}"))
      open_the_grid(grid_body_markup(grid_column_markup(block)))
      open_first_block_form
      text_editor = "tinymce.get(jQuery('#ow_inline_modal textarea').attr('id'))"
      wait_for_text_editor(text_editor)

      expect(page.evaluate_script("#{text_editor}.getContent()")).to eq('<p>editor text</p>')
      expect(post_text_editor_in_place?).to be(true)
    end

    it 'keeps the text editor when the author saves a text block that holds an element with the id of its panel' do
      open_the_grid(grid_with_block("<p>text</p>#{panel_of_the_text_editor}"))
      open_first_block_form
      find('#ow_inline_modal .modal_submit').click
      expect(page).to have_no_css('#ow_inline_modal')

      expect(post_text_editor_in_place?).to be(true)
    end

    it 'lists the label and the content of a tab whose link and pane carry the id' do
      tabs = %(<ul class="nav nav-tabs"><li class="active"><a href="#t0" id="#{id}">One</a></li></ul>) +
             %(<div class="tab-content"><div class="tab-pane active" id="#{id}"><p>tab text</p></div></div>)
      open_the_grid(grid_with_block(tabs, kind: 'tab'))
      open_first_block_form

      expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'One')
      expect(listed_item_content).to eq('<p>tab text</p>')
    end

    it 'lists an accordion panel whose chevron and heading carry the id, and keeps the text editor' do
      accordion = [
        %(<div class="panel panel-default"><div class="panel-heading" id="#{id}"><h4 class="panel-title">),
        %(<a>One <i class="glyphicon glyphicon-chevron-up pull-right" id="#{id}"></i></a></h4></div>),
        %(<div class="panel-collapse collapse"><div class="panel-body"><p>panel text</p></div></div></div>)
      ].join
      open_the_grid(grid_with_block(accordion, kind: 'accordion'))
      open_first_block_form

      expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'One')
      expect(listed_item_content).to eq('<p>panel text</p>')
      expect(post_text_editor_in_place?).to be(true)
    end

    it 'lists the caption of a slide whose caption carries the id' do
      slide = %(<div class="carousel-inner"><div class="item active"><img src="#{ONE_PIXEL_IMAGE}" alt="">) +
              %(<div class="carousel-caption" id="#{id}"><p>caption</p></div></div></div>)
      open_the_grid(grid_with_block(slide, kind: 'slider'))
      open_first_block_form
      find('#ow_inline_modal td.name', text: 'data:image')

      expect(listed_item_content).to eq('<p>caption</p>')
    end
  end
end
