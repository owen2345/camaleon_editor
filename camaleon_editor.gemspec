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

  # 2.9.3 brought the shared markup detector (CamaleonCms::UnsafeMarkup) and the post content
  # allowlists the grid template scan is built on; on an older core there would be no scan.
  s.add_dependency 'camaleon_cms', '>= 2.9.3'
  s.add_dependency 'rails'
  # The text editors keep scripts by ways of TinyMCE's that hold from 4.7.4 on: an older one gives a
  # script's text back inside a CDATA wrapper and puts a paragraph around a script at the top level
  # of the content. Core asks for a tinymce-rails below 5.
  s.add_dependency 'tinymce-rails', '>= 4.7.4'
end
