# frozen_string_literal: true

# Installing a Camaleon site (default plugins, theme, sample content, admin user) is expensive, so
# install one canonical site per suite run -- committed outside the per-example transactions so every
# example can reuse it through CamaleonCms::Site.first; example-level mutations still roll back with
# their transaction. The per-example cache resets this relies on live in rails_helper's config.before.
RSpec.configure do |config|
  config.before(:suite) do
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
      connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
    end
    # Drop caches memoized during boot (they may hold sites the purge just deleted);
    # set_default_user_roles resolves Site.main_site while installing.
    CamaleonCms::Site.instance_variable_set(:@main_site, nil)
    PluginRoutes.instance_variable_set(:@all_sites, nil)
    PluginRoutes.instance_variable_get(:@cache)&.clear
    site = FactoryBot.create(:site)
    # The shared site has the plugin, so the plugin_install call of an example returns early. Without
    # this row, each call draws the routes again: the transaction of the example rolls its row back.
    # An example that needs a site without the plugin uninstalls it or uses init_site(fresh: true).
    CurrentRequest.site = site.decorate
    plugin_install('camaleon_editor')
  ensure
    CurrentRequest.reset
  end
end
