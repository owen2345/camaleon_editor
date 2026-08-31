# frozen_string_literal: true

# The editor permission labels are short, literal names (kept the same across locales so they read
# as a product name in the roles form); the descriptions beside them are translated.
RSpec.describe 'the editor permission labels', type: :model do
  it 'exposes the short label name in every shipped locale' do
    %i[en es it].each do |locale|
      expect(I18n.t('camaleon_editor.permission.label', locale: locale)).to eq('Grid Editor')
      expect(I18n.t('camaleon_editor.permission.manage_label', locale: locale)).to eq('Grid templates')
    end
  end

  # The hook resolves label/description from the locale file with no in-code default:, so a missing
  # or misnested key surfaces as a translation-missing string rather than being silently absorbed.
  it 'resolves every permission string from the locale file, not an in-code default' do
    keys = %i[label description manage_label manage_description]
    locales = %i[en es it]
    keys.each do |key|
      locales.each do |locale|
        value = I18n.t("camaleon_editor.permission.#{key}", locale: locale)
        expect(value).to be_present
        expect(value).not_to include('translation missing')
      end
    end
  end
end
