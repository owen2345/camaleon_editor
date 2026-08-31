# frozen_string_literal: true

# The roles form hook (camaleon_editor_available_user_roles_list) must register the permission
# without mutating the process-global CamaleonCms::UserRole::ROLES constant that the CMS hands it:
# a mutation would append one more checkbox on every roles-form render and leak across sites.
RSpec.describe 'the roles form registers the editor permission safely' do
  include Plugins::CamaleonEditor::MainHelper
  init_site

  let(:admin) { CamaManager.get_user_class_name.constantize.find_by!(username: 'admin') }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    sign_in_as(admin, site: @site)
  end

  it 'renders the permission checkbox exactly once across repeated renders' do
    2.times { get '/admin/user_roles/new' }

    expect(response.body.scan('rol_values[manager][camaleon_editor]').size).to eq(1)
  end

  it 'does not append to the shared UserRole::ROLES constant' do
    before_count = CamaleonCms::UserRole::ROLES[:manager].size

    get '/admin/user_roles/new'

    expect(CamaleonCms::UserRole::ROLES[:manager].size).to eq(before_count)
    expect(CamaleonCms::UserRole::ROLES[:manager]).not_to include(a_hash_including(key: 'camaleon_editor'))
  end

  it 'is a no-op when the roles list has an unexpected shape' do
    expect { camaleon_editor_available_user_roles_list({ roles_list: {} }) }.not_to raise_error
    expect { camaleon_editor_available_user_roles_list({}) }.not_to raise_error
  end
end
