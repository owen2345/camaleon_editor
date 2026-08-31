# frozen_string_literal: true

# The grid editor is gated by the plugin's own default-off permission (:manage, :camaleon_editor),
# granted per role in the admin roles form; admins always pass (can :manage, :all). The core
# plugins-manager permission is plugin administration and does not open the editor.
RSpec.describe 'Security: the camaleon_editor permission' do
  init_site

  let(:admin) { CamaManager.get_user_class_name.constantize.find_by!(username: 'admin') }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
  end

  # A user whose role holds exactly the given manager grants.
  def user_with_manager_grants(manager_meta, slug)
    role = @site.user_roles.create!(name: slug, slug: slug)
    role.set_meta("_manager_#{@site.id}", manager_meta)
    create(:user, role: slug, site: @site)
  end

  # Assert the request was refused by the authorization gate specifically -- CanCan::AccessDenied
  # redirects to the admin dashboard with a flash error -- not by the plugin-inactive redirect
  # (which goes to the site root) or an unauthenticated redirect (which goes to the login page).
  def expect_authorization_denied
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include('/admin/dashboard')
    expect(flash[:error]).to be_present
  end

  it 'refuses the grid-template endpoints to a plugins manager without the grant' do
    sign_in_as(user_with_manager_grants({ plugins: 1 }, 'plugins-manager'), site: @site)

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect_authorization_denied
  end

  it 'admits a role granted only the camaleon_editor permission' do
    sign_in_as(user_with_manager_grants({ camaleon_editor: 1 }, 'grid-editor-user'), site: @site)

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect(response).to have_http_status(:ok)
  end

  it 'refuses a role with no grants at all' do
    sign_in_as(user_with_manager_grants({}, 'no-grants'), site: @site)

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect_authorization_denied
  end

  it 'still admits admins everywhere' do
    sign_in_as(admin, site: @site)

    get '/admin/plugins/camaleon_editor/grid_editor'

    expect(response).to have_http_status(:ok)
  end

  it 'offers the permission as a checkbox in the roles form' do
    sign_in_as(admin, site: @site)

    get '/admin/user_roles/new'

    expect(response.body).to include('rol_values[manager][camaleon_editor]')
    expect(response.body).to include('Visual grid editor')
  end

  it 'does not load the editor assets in the post form for a non-granted author' do
    post_type = @site.post_types.first
    author = user_with_manager_grants({}, 'post-author')
    @site.user_roles.find_by(slug: 'post-author').set_meta("_post_type_#{@site.id}",
                                                           { edit: [post_type.id.to_s] })
    sign_in_as(author, site: @site)

    get "/admin/post_type/#{post_type.id}/posts/new"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('editor-manifest')
  end
end
