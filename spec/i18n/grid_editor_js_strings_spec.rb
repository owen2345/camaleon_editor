# frozen_string_literal: true

# Core's admin layout hands the browser the camaleon_cms.admin.js tree of the current language and
# nothing else. A string the editor's scripts ask for has to be in that tree: one that is not comes
# out in every language as the default the script passes, the English string, and without a default
# as the last segment of its key, titleized ("List" for "List of templates").
RSpec.describe 'the grid editor strings its scripts read', type: :model do
  # Every call that names its key, as [key, English default or nil]: I18n("grid_editor.<key>", ...)
  # for the labels and prompts, tooltip("grid_editor.<key>", ...) for the tooltips, and
  # report_failure("<key>", ...) for the failure messages.
  def script_calls
    scripts = Rails.root.glob('../../app/assets/javascripts/plugins/camaleon_editor/admin/*.js')
    call = /(?:(?:I18n|tooltip)\(\s*["']grid_editor\.|report_failure\(\s*["'])(\w+)["'](?:\s*,\s*"([^"]*)")?/
    scripts.flat_map { |script| script.read.scan(call) }
  end

  def script_keys
    script_calls.map(&:first).uniq
  end

  it 'finds the keys the scripts ask for' do
    expect(script_keys).to include('list', 'contents', 'toggle_editor', 'clear', 'preview', 'fullscreen',
                                   'list_title', 'col_block_title', 'switch_editor',
                                   'audio_form', 'add_item', 'edit_item', 'style_blue',
                                   'block_tab', 'block_tab_hint',
                                   'import_failed', 'request_failed', 'content_unreadable', 'editor_failed')
  end

  it 'ships every one of them, in every language, in the tree core exports' do
    expect_shipped_translations('camaleon_cms.admin.js.grid_editor', script_keys)
  end

  # The browser gets the strings of the current admin language alone, and core ships more languages
  # than the plugin: in one of those the default the script passes is all there is. It is a second
  # copy of the English string, so it has to say the same thing.
  it 'gives every string an English default that says what the English locale string says' do
    script_calls.each do |key, default|
      english = I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: :en)
      expect(default).to eq(english),
                         "#{key}: the script's default is #{default.inspect}, the locale's #{english.inspect}"
    end
  end

  # A value the script fills in (a column block's width) is named the same in every language: core's
  # helper replaces the placeholder it is given and leaves one of any other name in the string.
  it 'names the values a string takes the same in every language' do
    script_keys.each do |key|
      placeholders = SHIPPED_LOCALES.index_with do |locale|
        I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: locale).scan(/%\{\w+\}/).sort
      end
      expect(placeholders.values.uniq.size).to eq(1), "#{key}: #{placeholders.inspect}"
    end
  end

  it 'keeps no string where the browser never sees it' do
    SHIPPED_LOCALES.each do |locale|
      expect(I18n.t('admin.js.grid_editor', locale: locale, default: nil)).to be_nil
    end
  end
end
