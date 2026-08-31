# Change Log

## Unreleased

### The gem loads standalone; modern tooling and a spec harness

`MainHelper` included a helper constant defined nowhere in the gem, so the published gem raised `NameError` at host-app boot; its methods are now part of the gem. Also modernizes the gemspec and Gemfile (`required_ruby_version >= 3.0`, `camaleon_cms >= 2.9.4`, Ruby 3.4.10 toolchain) and adds a camaleon_cms-backed RSpec suite covering boot, activation, grid-template CRUD, the hooks and the admin editor UI. [#5](https://github.com/owen2345/camaleon_editor/pull/5).
