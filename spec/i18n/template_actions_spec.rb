# frozen_string_literal: true

# The templates list renders its apply action's tooltip and confirm prompt on the server, from the
# plugin's own locale file; a missing key would surface as a translation-missing string in both.
RSpec.describe 'the template apply action strings', type: :model do
  it 'resolves in every shipped locale' do
    expect_shipped_translations('camaleon_editor.templates', %i[apply apply_confirm])
  end

  # Strings the editor's script reads reach the browser only from the camaleon_cms.admin.js tree.
  it 'ships the failure messages where the admin layout exports them, in every locale' do
    expect_shipped_translations('camaleon_cms.admin.js.grid_editor',
                                %i[import_failed request_failed content_unreadable])
  end

  # The browser only gets the strings of the current admin language, so the script carries an English
  # default for the languages the plugin does not ship. That default is a second copy of the English
  # string: it has to say the same thing.
  it 'keeps the English defaults in the editor script equal to the English locale strings' do
    script = Rails.root.join('../../app/assets/javascripts/plugins/camaleon_editor/admin/grid-editor.js').read
    defaults = script.scan(/report_failure\("(\w+)", "([^"]+)"\)/).to_h

    expect(defaults.keys).to include('import_failed', 'request_failed', 'content_unreadable')
    defaults.each do |key, text|
      expect(text).to eq(I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: :en))
    end
  end
end
