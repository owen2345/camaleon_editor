# frozen_string_literal: true

# Core's admin layout hands the browser the camaleon_cms.admin.js tree of the current language and
# nothing else. A string the editor's scripts ask for has to be in that tree: one that is not comes
# out as the last segment of its key, titleized ("List" for "List of templates"), in every language.
RSpec.describe 'the grid editor strings its scripts read', type: :model do
  # Every call that names its key, as [key, English default or nil].
  def script_calls
    scripts = Rails.root.glob('../../app/assets/javascripts/plugins/camaleon_editor/admin/*.js')
    scripts.flat_map { |script| script.read.scan(/I18n\(\s*["']grid_editor\.(\w+)["'](?:\s*,\s*"([^"]*)")?/) }
  end

  def script_keys
    script_calls.map(&:first).uniq
  end

  it 'finds the keys the scripts ask for' do
    expect(script_keys).to include('list', 'contents', 'toggle_editor', 'clear', 'preview', 'fullscreen')
  end

  it 'ships every one of them, in every language, in the tree core exports' do
    expect_shipped_translations('camaleon_cms.admin.js.grid_editor', script_keys)
  end

  # The browser gets the strings of the current admin language alone, and core ships more languages
  # than the plugin: in one of those the default the script passes is all there is. It is a second
  # copy of the English string, so it has to say the same thing.
  it 'gives every string an English default that says what the English locale string says' do
    script_calls.each do |key, default|
      expect(default).to eq(I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: :en)),
                         "no such default for #{key}"
    end
  end

  it 'keeps no string where the browser never sees it' do
    SHIPPED_LOCALES.each do |locale|
      expect(I18n.t('admin.js.grid_editor', locale: locale, default: nil)).to be_nil
    end
  end
end
