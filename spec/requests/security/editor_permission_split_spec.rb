# frozen_string_literal: true

# The editor is gated by two default-off permissions: PERMISSION_USE (apply templates / get the
# toolbar) covers the read actions, PERMISSION_MANAGE covers template-library CRUD, and the plugin's
# `settings` action stays under :manage,:plugins. Admins pass everything.
RSpec.describe 'Security: the editor use/manage permission split' do
  init_site

  let(:use) { Plugins::CamaleonEditor::MainHelper::PERMISSION_USE }
  let(:manage) { Plugins::CamaleonEditor::MainHelper::PERMISSION_MANAGE }
  let(:base) { '/admin/plugins/camaleon_editor/grid_editor' }

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
  end

  context 'with a use-only grant' do
    before { sign_in_as(user_with_manager_grants({ use => 1 }, 'use-only'), site: @site) }

    it 'may read the template list' do
      get base
      expect(response).to have_http_status(:ok)
    end

    it 'may not create a template' do
      expect do
        post base, params: { grid_template: { name: 'Nope', description: '<div>x</div>' } }
      end.not_to(change { @site.grid_templates.count })
      expect(response.location).to include('/admin/dashboard')
      expect(flash[:error]).to be_present
    end

    it 'may not destroy a template' do
      template = @site.grid_templates.create!(name: 'Shared', slug: 'shared', description: '<div>x</div>')

      delete "#{base}/#{template.id}"

      expect(response.location).to include('/admin/dashboard')
      expect(flash[:error]).to be_present
      expect(@site.grid_templates.where(id: template.id)).to exist
    end
  end

  context 'with a manage grant' do
    before { sign_in_as(user_with_manager_grants({ manage => 1 }, 'manager'), site: @site) }

    it 'may read the template list' do
      get base
      expect(response).to have_http_status(:ok)
    end

    it 'may create a template' do
      post base, params: { grid_template: { name: 'Made', description: '<div>x</div>' } }

      expect(response).to have_http_status(:ok)
      expect(@site.grid_templates.find_by(name: 'Made')).to be_present
    end

    it 'may destroy a template' do
      template = @site.grid_templates.create!(name: 'Doomed', slug: 'doomed', description: '<div>x</div>')

      delete "#{base}/#{template.id}"

      expect(response).to have_http_status(:ok)
      expect(@site.grid_templates.where(id: template.id)).not_to exist
    end
  end

  it 'registers both permission checkboxes, keyed to the gate constants' do
    sign_in_as(cama_admin_user, site: @site)

    get '/admin/user_roles/new'

    expect(response.body).to include("rol_values[manager][#{use}]")
    expect(response.body).to include("rol_values[manager][#{manage}]")
  end

  it 'admits a role granted the use permission by the same key the form renders (round trip)' do
    granted = user_with_manager_grants({ use.to_s => '1' }, 'form-granted')
    sign_in_as(granted, site: @site)

    get base

    expect(response).to have_http_status(:ok)
  end
end
