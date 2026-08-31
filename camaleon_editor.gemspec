# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'camaleon_editor/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'camaleon_editor'
  s.version     = CamaleonEditor::VERSION
  s.authors     = ['Owen']
  s.email       = ['owenperedo@gmail.com']
  s.homepage    = 'https://github.com/owen2345/camaleon_editor'
  s.summary     = 'Visual Editor Plugin for Camaleon CMS'
  s.description = 'Visual drag-and-drop grid/content editor plugin for Camaleon CMS'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.0'

  # No test_files: RubyGems merges it into `files`, which would ship the test suite to users.
  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  s.add_dependency 'rails'
end
