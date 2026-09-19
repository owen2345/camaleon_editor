# frozen_string_literal: true

# Grid markup the way the editor exports it, and the steps the grid editor feature specs share.

def grid_block_markup(inner, kind: 'text')
  %(<div class="" data-kind="#{kind}"><div class="grid_item_content grid_item_#{kind}">#{inner}</div></div>)
end

def grid_column_markup(inner = '', col: 6, title: '50%')
  %(<div class="col-md-#{col}" data-col="#{col}" data-col_title="#{title}">) +
    %(<div class="grid_sortable_items">#{inner}</div></div>)
end

def grid_body_markup(inner = grid_column_markup, attributes: '')
  %(<div class="panel_grid_body row"#{" #{attributes}" unless attributes.empty?}>#{inner}</div>)
end

# A grid of one column holding one block.
def grid_with_block(inner, kind: 'text')
  grid_body_markup(grid_column_markup(grid_block_markup(inner, kind: kind)))
end

# Post content is the grid behind the marker that names the libraries its blocks need.
def grid_post_content(body)
  "<div>[grid_editor data='']</div>#{body}"
end

# Written past the model: these specs are about what the editor does with content already stored.
def store_post_content(post, content)
  # rubocop:disable-next Rails/SkipsModelValidations
  CamaleonCms::Post.where(id: post.id).update_all(content: content)
end

def open_post_in_editor(post)
  store_current_site(@site)
  plugin_install('camaleon_editor')
  admin_sign_in
  visit "#{cama_root_relative_path}/admin/post_type/#{post.post_type.id}/posts/#{post.id}/edit"
end

def open_grid_editor
  accept_confirm { find('.mce-btn', text: 'Grid Editor').click }
end

def open_templates_menu
  find('.grid_editor_menu a.dropdown-toggle', text: 'Templates').click
end

def open_templates_list
  open_templates_menu
  find('.grid_editor_menu .list_templates').click
end

def apply_listed_template
  accept_confirm { find('#grid_table_list .import_item').click }
end

# What the editor would save for the post right now: the grid as the last auto_save exported it.
def saved_grid_content
  page.evaluate_script("jQuery('.panel_grid_editor').next('textarea').val()")
end

def trigger_grid_auto_save
  page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
end
