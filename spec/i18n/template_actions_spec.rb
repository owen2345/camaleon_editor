# frozen_string_literal: true

# The templates list renders its apply action's tooltip and confirm prompt on the server, from the
# plugin's own locale file; a missing key would surface as a translation-missing string in both.
RSpec.describe 'the template apply action strings', type: :model do
  it 'resolves in every shipped locale' do
    expect_shipped_translations('camaleon_editor.templates', %i[apply apply_confirm])
  end
end
