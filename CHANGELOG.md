# Change Log

## Unreleased

### Security: parse saved element styles as JSON, never eval

The grid editor recovered a block's saved style by running `eval()` on its `data-style` attribute, which rides along in a stored grid-template — so a crafted value ran as JavaScript in the editing user's browser. The value is now parsed with `JSON.parse` (it is written with `JSON.stringify`), and malformed input yields an empty style instead of executing. The accordion builder no longer shares that `data-style` name (it stored a plain panel class there): it uses `data-accordion-style`, falling back to the legacy attribute so existing accordions keep their style. [#9](https://github.com/owen2345/camaleon_editor/pull/9).

### Release pipeline

Adds the manually dispatched Release workflow (same pipeline as cama_contact_form and camaleon_cms): it verifies the requested version against `lib/camaleon_editor/version.rb`, RubyGems and existing tags, requires a green CI run for the released commit, builds the gem with `--strict`, audits the packaged files, publishes to RubyGems, then tags and creates the GitHub release with the version's CHANGELOG section as notes. Development tooling only. [#8](https://github.com/owen2345/camaleon_editor/pull/8).

### Security: editor permissions, and no ERB evaluation of templates

Stored grid-template values were ERB-evaluated as server-side code; they now come back verbatim. The editor is gated by two new default-off permissions, **Grid Editor** and **Grid templates**; admins pass. [#7](https://github.com/owen2345/camaleon_editor/pull/7).

**Breaking changes**
- Non-admin roles need the new permissions (Admin > Users > Roles); the plugins permission alone no longer opens it.

### RuboCop and CI

Adds RuboCop (same plugin set as camaleon_cms), lint-cleans the codebase with behavior-preserving fixes, and adds a CI workflow running the RSpec suite and RuboCop on every push and pull request. Also documents the development setup in the README. Development tooling only — the packaged gem's behavior is unchanged. [#6](https://github.com/owen2345/camaleon_editor/pull/6).

### The gem loads standalone; modern tooling and a spec harness

`MainHelper` included a helper constant defined nowhere in the gem, so the published gem raised `NameError` at host-app boot; its methods are now part of the gem. Also modernizes the gemspec and Gemfile (`required_ruby_version >= 3.0`, `camaleon_cms >= 2.9.4`, Ruby 3.4.10 toolchain) and adds a camaleon_cms-backed RSpec suite covering boot, activation, grid-template CRUD, the hooks and the admin editor UI. [#5](https://github.com/owen2345/camaleon_editor/pull/5).
