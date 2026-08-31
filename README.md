# CamaleonEditor - Camaleon CMS Plugin

A visual drag-and-drop grid/content editor plugin for [Camaleon CMS](https://github.com/owen2345/camaleon-cms):
it adds a "Grid Editor" mode to the admin post editor, reusable grid templates, and a `grid_editor`
frontend shortcode.

![](screenshot.png)

## More Information:
https://camaleon.website/store/plugins/camaleon_editor

## Permissions

The editor is available to administrators, and to any role granted the plugin's own
**Visual grid editor** permission (Admin > Users > Roles). The permission is off by
default: without it, users get the plain post editor, and the grid-template endpoints refuse them.

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
