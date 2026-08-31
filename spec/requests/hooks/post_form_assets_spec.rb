# frozen_string_literal: true

# The new_post/edit_post hooks (camaleon_editor_post_form) append the admin_grid_editor asset library
# -- the editor JS manifest and its stylesheet -- so the grid editor is available in the admin post
# form, and only there, and only while the plugin is active.
RSpec.describe 'the post-form hook' do
  init_site

  let(:admin) { cama_admin_user }
  let(:post_type) { CamaleonCms::Site.first.post_types.first }

  before { sign_in_as(admin, site: @site) }

  context 'with the plugin active' do
    before do
      store_current_site(@site)
      plugin_install('camaleon_editor')
    end

    it 'appends the grid-editor asset libraries to the admin post form' do
      get "/admin/post_type/#{post_type.id}/posts/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('editor-manifest')
      expect(response.body).to include('grid-editor-manifest')
    end

    it 'does not load the editor libraries on unrelated admin pages' do
      get '/admin/dashboard'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('editor-manifest')
    end
  end

  context 'with the plugin inactive' do
    it 'leaves the admin post form untouched' do
      get "/admin/post_type/#{post_type.id}/posts/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('editor-manifest')
    end
  end

  # The positive path for a non-admin: an admin passes via can :manage,:all, so it does not exercise
  # the permission. A granted non-admin author must actually get the editor assets.
  context 'with a granted non-admin author' do
    let(:author) do
      user_with_manager_grants({ Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1 }, 'grid-author',
                               post_type_meta: { edit: [post_type.id.to_s] })
    end

    before do
      store_current_site(@site)
      plugin_install('camaleon_editor')
      sign_in_as(author, site: @site)
    end

    it 'appends the editor assets when the author holds the use permission' do
      get "/admin/post_type/#{post_type.id}/posts/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('editor-manifest')
    end
  end
end
