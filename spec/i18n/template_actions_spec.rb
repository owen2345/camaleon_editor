# frozen_string_literal: true

# The templates list renders its apply action's tooltip and confirm prompt on the server, from the
# plugin's own locale file; a missing key would surface as a translation-missing string in both.
RSpec.describe 'the template apply action strings', type: :model do
  it 'resolves in every shipped locale' do
    keys = %i[apply apply_confirm]
    %i[en es it].each do |locale|
      keys.each do |key|
        value = I18n.t("camaleon_editor.templates.#{key}", locale: locale)
        expect(value).to be_present
        expect(value).not_to include('translation missing')
      end
    end
  end

  # Strings the editor's script reads reach the browser only from the camaleon_cms.admin.js tree.
  it 'ships the failure messages where the admin layout exports them, in every locale' do
    keys = %i[import_failed request_failed content_unreadable]
    %i[en es it].each do |locale|
      keys.each do |key|
        value = I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: locale)
        expect(value).not_to include('translation missing')
        expect(value).not_to include('Translation missing')
      end
    end
  end
end
