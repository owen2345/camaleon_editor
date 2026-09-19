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
end
