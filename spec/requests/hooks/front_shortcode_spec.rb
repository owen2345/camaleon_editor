# frozen_string_literal: true

# The front_before_load hook (camaleon_editor_front) registers the grid_editor shortcode. When a
# rendered post uses it, the shortcode is consumed and its callback appends the plugin's frontend
# stylesheet library.
RSpec.describe 'the front hook' do
  init_site

  let(:admin) { CamaManager.get_user_class_name.constantize.find_by!(username: 'admin') }

  # grid_editor is a registered shortcode, so seeding post content that contains it goes through the
  # content-shortcode gate; store an admin as the acting user so the fixture save is allowed.
  before { store_current_user(admin) }

  context 'with the plugin active' do
    before do
      store_current_site(@site)
      plugin_install('camaleon_editor')
    end

    it 'consumes the grid_editor shortcode and appends the front stylesheet' do
      @post.object.update!(content: 'before [grid_editor] after')

      get '/sample-post'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('[grid_editor]')
      expect(response.body).to include('plugins/camaleon_editor/front/basic')
    end
  end

  context 'with the plugin inactive' do
    it 'renders the shortcode text verbatim and loads no plugin stylesheet' do
      @post.object.update!(content: 'before [grid_editor] after')

      get '/sample-post'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('[grid_editor]')
      expect(response.body).not_to include('plugins/camaleon_editor/front/basic')
    end
  end
end
