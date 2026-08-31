# frozen_string_literal: true

# The editor permission's label must be localized in every locale the plugin ships, not left as the
# English string beside a translated description.
RSpec.describe 'the editor permission labels are localized' do
  it 'translates the label in each shipped locale' do
    expect(I18n.t('camaleon_editor.permission.label', locale: :en)).to eq('Visual grid editor')
    expect(I18n.t('camaleon_editor.permission.label', locale: :es)).to eq('Editor visual de rejilla')
    expect(I18n.t('camaleon_editor.permission.label', locale: :it)).to eq('Editor visuale a griglia')
  end
end
