# frozen_string_literal: true

source 'https://rubygems.org'

# Declare your gem's dependencies in camaleon_editor.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

gem 'camaleon_cms', '>= 2.9.4'
gem 'sprockets-rails', '>= 3.5.2'

# Development/test dependencies (none are shipped in the packaged gem). A camaleon_cms-backed dummy
# Rails app under spec/ is booted under RSpec.
group :development do
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
  gem 'sqlite3'

  # Feature specs (:js) drive the admin UI through a real headless Chrome via Capybara + Selenium.
  # puma is the Capybara rack server; capybara-screenshot saves a screenshot when a :js example fails.
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'puma'
  gem 'selenium-webdriver'

  # Linting -- same rubocop plugin set as camaleon_cms, so style stays consistent across the two.
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
end
