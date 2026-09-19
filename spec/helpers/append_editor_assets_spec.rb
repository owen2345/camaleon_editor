# frozen_string_literal: true

# camaleon_editor_append_editor_assets is the one call that loads the editor into an admin page:
# the post-form hook makes it, and a host page or another plugin may make it too, in the same
# request. However often it is made, the page gets the editor, and its declaration, once.
RSpec.describe 'loading the editor assets', type: :model do
  let(:host) do
    Class.new do
      include Plugins::CamaleonEditor::MainHelper

      attr_reader :libraries, :contents, :request

      def initialize(manager:)
        @manager = manager
        @libraries = []
        @contents = []
        @request = Struct.new(:env).new({})
      end

      def can?(*) = @manager
      def plugin_gem_asset(path, _plugin) = path
      def append_asset_libraries(libraries) = @libraries << libraries
      def append_asset_content(content) = @contents << content
    end
  end

  it 'declares a template manager with a literal true, once however often it is called' do
    page = host.new(manager: true)

    2.times { page.camaleon_editor_append_editor_assets }

    expect(page.contents).to eq(['<script>var cama_grid_editor_can_manage_templates = true;</script>'])
    expect(page.libraries.size).to eq(1)
  end

  it 'declares anyone else with a literal false, whatever the ability check answers with' do
    page = host.new(manager: nil)

    page.camaleon_editor_append_editor_assets

    expect(page.contents).to eq(['<script>var cama_grid_editor_can_manage_templates = false;</script>'])
  end
end
