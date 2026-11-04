# mycli

A cross-platform Go CLI tool, shipped as a single Go module and distributed as
prebuilt binaries.

## Getting started

Tooling and tasks are managed with [mise](https://mise.jdx.dev). Install mise,
then:

```sh
mise install      # install Go, goreleaser, golangci-lint at pinned versions
mise tasks        # list all available tasks
```

## Day-to-day tasks

| Task                      | What it does                                  |
| ------------------------- | --------------------------------------------- |
| `mise run build`          | Build the binary into `./dist`                |
| `mise run test`           | Run the test suite                            |
| `mise run lint`           | Run `golangci-lint`                           |
| `mise run fmt`            | Format all Go source                          |
| `mise run run -- <args>`  | Run the CLI locally                           |
| `mise run tidy`           | `go mod tidy`                                 |
| `mise run ci`             | Lint + test + fmt check (what CI runs)        |

## Releasing

Releases use [goreleaser](https://goreleaser.com) and build binaries for
linux/darwin/windows on amd64/arm64.

| Task                       | What it does                                |
| -------------------------- | ------------------------------------------- |
| `mise run release-check`   | Validate `.goreleaser.yaml`                 |
| `mise run release-snapshot`| Local snapshot build (no tag, no publish)   |
| `mise run release`         | Cut a real release (requires a pushed tag)  |

```sh
git tag v0.1.0
git push origin v0.1.0
mise run release
```

## Docs

Documentation is built with [mkdocs](https://www.mkdocs.org):

```sh
mise run docs-serve   # local preview with live reload
mise run docs-build   # build the static site into ./site
```
