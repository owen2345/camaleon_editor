# CamaleonEditor - Camaleon CMS Plugin

A visual drag-and-drop grid/content editor plugin for [Camaleon CMS](https://github.com/owen2345/camaleon-cms):
it adds a "Grid Editor" mode to the admin post editor, reusable grid templates, and a `grid_editor`
frontend shortcode.

![](screenshot.png)

## More Information:
https://camaleon.website/store/plugins/camaleon_editor

## Permissions

The plugin adds two role permissions under **Admin > Users > Roles**, both off by default
(administrators always have them):

- **Grid Editor** — use the editor in the post form and apply saved templates. Without it, a user
  gets the plain post editor.
- **Grid templates** — create, edit and delete the site's shared grid templates.

A template is markup the editor puts into the page of whoever applies it. From a **Grid templates**
holder, markup that core refuses as post content (scripts, event handlers, embeds) is refused when
the template is saved; it is never rewritten. The editor's own blocks are accepted, except a Video
block that embeds a frame (YouTube, Vimeo). Administrators are not scanned, nor is a role core
trusts with unfiltered HTML (**Allow unfiltered HTML in post content**, for any post type). Server-side
code that owns its markup (a seed, an import) opts out with `template.unfiltered_description!`
before saving; without a signed-in author a template is scanned.

Plugin settings stay under the core **plugins** permission. A role holding neither editor permission
is refused the grid-template endpoints.

## Loading the editor on another admin page

The plugin loads the grid editor into the post form by itself. To offer it on a TinyMCE field of
another admin page (a theme settings page, another plugin's form), call the plugin's helper from
that page's controller or view, after checking the user may use the editor:

```ruby
camaleon_editor_append_editor_assets if can?(:manage, Plugins::CamaleonEditor::MainHelper::PERMISSION_USE)
```

The helper appends the editor's scripts and stylesheet, and tells the editor whether the user holds
the **Grid templates** permission, which decides whether **Templates > Save as template** is
offered. A page that appends the asset library directly still works: when the Templates menu is
first opened the editor asks `GET /admin/plugins/camaleon_editor/abilities`, which answers `{"manage_templates": true|false}`
to any user holding either editor permission, and offers the entry only on a `true`.

## Development

The suite runs against a camaleon_cms-backed dummy Rails app under `spec/` (the Ruby version comes
from `.tool-versions`):

```bash
bundle install
(cd spec/dummy && RAILS_ENV=test bin/rails db:test:prepare)
bin/rspec
```

The `:js` feature specs drive a headless Chrome via Capybara + Selenium; a local Chrome install is
all they need (Selenium Manager resolves a matching chromedriver).

Lint with the same configuration CI enforces:

```bash
bin/rubocop
```

## Releasing

Bump `lib/camaleon_editor/version.rb`, cut a `## <version>` section in `CHANGELOG.md`, merge, then
run the **Release** workflow from the Actions tab on `master`, typing that same version. The
workflow refuses to run without a green CI run for the released commit, publishes the gem to
RubyGems, and creates the tag and GitHub release.
