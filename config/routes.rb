Rails.application.routes.draw do

  #Admin Panel
  scope 'admin', as: 'admin' do
    namespace 'plugins' do
      namespace 'camaleon_editor' do
        resources :grid_editor, controller: "admin"
        get "style-settings" => "admin#style_settings"
      end
    end
  end

  # main routes
  #scope 'camaleon_editor', module: 'plugins/camaleon_editor/', as: 'camaleon_editor' do
  #  Here my routes for main routes
  #end
end
