# Publishing codelessly_sdk

The package is published from the repository root, under its own name, after
`codelessly_api` (publish the API first: see CodelesslyAPI's PUBLISHING.md).

## Developing against an unpublished API

`pubspec.yaml` depends on the hosted API (`codelessly_api: ^<version>`). To work
against a sibling CodelesslyAPI checkout, put a `pubspec_overrides.yaml` next to
the pubspec (it is gitignored; CI writes the same files):

```yaml
# pubspec_overrides.yaml
dependency_overrides:
  codelessly_api:
    path: ../CodelesslyAPI
```

and in `example/pubspec_overrides.yaml` the same with `path: ../../CodelesslyAPI`.

## Publishing

1. Publish the `codelessly_api` version the SDK needs, and set the SDK's
   `codelessly_api:` constraint to it.
2. Set `version:` in `pubspec.yaml` and add its entry at the top of
   `CHANGELOG.md`.
3. Remove (or move aside) `pubspec_overrides.yaml` and
   `example/pubspec_overrides.yaml`: the SDK must resolve against the published
   API.
4. Check, from a clean checkout:

   ```sh
   flutter pub get
   flutter analyze
   flutter test
   (cd example && flutter analyze && flutter test)
   flutter pub publish --dry-run   # 0 warnings
   ```

5. Commit, tag (`git tag v<version>`) and publish:

   ```sh
   flutter pub publish
   ```

`.pubignore` lists what stays out of the package: `tool/`, `docs/` (the guide
is read on GitHub, `documentation:` in the pubspec), `test/` with its fixtures,
the example's platform folders (`flutter create .` makes them) and local state.
