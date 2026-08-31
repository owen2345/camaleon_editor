# Change Log

## Unreleased

### Security: editor permission, and no ERB evaluation of templates

Stored grid-template values were rendered as inline ERB templates — server-side Ruby execution; they are now returned verbatim. The editor is gated by a new default-off **Visual grid editor** permission; admins always pass. [#7](https://github.com/owen2345/camaleon_editor/pull/7).

**Breaking changes**
- Non-admin roles need the new permission (Admin > Users > Roles); the plugins permission alone no longer opens the editor.

### RuboCop and CI

Adds RuboCop (same plugin set as camaleon_cms), lint-cleans the codebase with behavior-preserving fixes, and adds a CI workflow running the RSpec suite and RuboCop on every push and pull request. Also documents the development setup in the README. Development tooling only — the packaged gem's behavior is unchanged. [#6](https://github.com/owen2345/camaleon_editor/pull/6).

### The gem loads standalone; modern tooling and a spec harness

`MainHelper` included a helper constant defined nowhere in the gem, so the published gem raised `NameError` at host-app boot; its methods are now part of the gem. Also modernizes the gemspec and Gemfile (`required_ruby_version >= 3.0`, `camaleon_cms >= 2.9.4`, Ruby 3.4.10 toolchain) and adds a camaleon_cms-backed RSpec suite covering boot, activation, grid-template CRUD, the hooks and the admin editor UI. [#5](https://github.com/owen2345/camaleon_editor/pull/5).
