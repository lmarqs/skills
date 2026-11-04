# mycli

A cross-platform Go CLI tool.

## Development

This project uses [mise](https://mise.jdx.dev) to manage tools and tasks.

```sh
mise install        # install pinned tools (Go, goreleaser, golangci-lint)
mise run build      # build the binary into ./dist
mise run test       # run tests
mise run lint       # run golangci-lint
mise run fmt        # format source
```

## Releasing

Releases are cut with [goreleaser](https://goreleaser.com):

```sh
mise run release-check     # validate the goreleaser config
mise run release-snapshot  # build a local snapshot (no tag/publish)
git tag v0.1.0 && mise run release   # cut a real, published release
```

## Docs

Documentation is built with [mkdocs](https://www.mkdocs.org):

```sh
mise run docs-serve   # live-reload preview at http://127.0.0.1:8000
mise run docs-build   # build the static site into ./site
```
