# Contributing

Start with [README.md](README.md) for the project overview,
[ARCHITECTURE.md](ARCHITECTURE.md) for package boundaries, and
[CLAUDE.md](CLAUDE.md) for the established engineering conventions.

## Local setup

Use a Flutter SDK that includes Dart compatible with the affected package manifests. Core and CLI require Dart `^3.9.0`; Studio requires `^3.10.8`. There is no root `pubspec.yaml`; resolve
dependencies and run tools inside each package.

From the repository root:

```bash
# Pure Dart packages
for pkg in zarvan_schema zarvan_core zarvan_eye zarvan_api zarvan_cli; do
  (cd packages/$pkg && dart pub get) || exit 1
done
# Flutter packages
for pkg in zarvan_flutter zarvan_platformer zarvan_strategy zarvan_idle zarvan_quiz zarvan_ads zarvan_studio; do
  (cd packages/$pkg && flutter pub get) || exit 1
done
```

The checked-in `pubspec_overrides.yaml` files make the shell, platformer,
and CLI use sibling packages during local development. Preserve the Git
dependencies in `pubspec.yaml`: consumers need consistent repository refs.
Local overrides do not validate external Git dependency resolution.

Inspect each manifest before testing a generated game against a particular ref. Internal Git dependencies and the generated project's engine ref must agree.

## Validation

Run these from the repository root for the packages affected by a change,
including downstream packages when a shared API changes:

```bash
# Run only affected packages and their downstream dependents, or all:
for pkg in zarvan_schema zarvan_core zarvan_eye zarvan_api zarvan_cli; do
  (cd packages/$pkg && dart analyze --fatal-infos && dart test) || exit 1
done
for pkg in zarvan_flutter zarvan_platformer zarvan_strategy zarvan_idle zarvan_quiz zarvan_ads zarvan_studio; do
  (cd packages/$pkg && flutter analyze --fatal-infos && flutter test) || exit 1
done
# Documentation
python -m pip install -r docs/requirements.txt
mkdocs build --strict
```

Format changed Dart files with `dart format`. Add regression tests for bug
fixes and behavioral tests for new features. For documentation-only edits,
check local links, examples against source, and `git diff --check`.
The workflows in [.github/workflows](.github/workflows) define the package
CI checks and their path filters.

For hot-path changes, also run the relevant benchmarks under
`packages/zarvan_core/benchmark/` and `packages/zarvan_platformer/benchmark/`.
For CLI or dependency changes, verify a generated game resolves dependencies
and builds against the intended published Git ref; local package tests alone
do not cover that integration. Publishing or pushing requires authorization.

## Trying the engine

Run the local CLI from its package directory:

```bash
cd packages/zarvan_cli
dart run bin/zarvan.dart --help
```

See [the CLI guide](packages/zarvan_cli/README.md) for `create`, `upgrade`,
`lint`, and `pack-assets`. Generated games are separate Flutter projects.
The ignored `test_game/` directory may exist in a developer checkout but
is not supplied by a fresh clone. Keep local sample games out of commits.

## Submitting changes

Keep changes focused, document public API changes in the relevant package
README, and update [CHANGELOG.md](CHANGELOG.md) for completed work.
Use [TODO.md](TODO.md) for remaining tasks and
[TODO.md](TODO.md)'s "Parked decisions" for parked rendering discussions.
Describe the problem, resulting behavior, and checks performed in a pull
request. Explain why a fix works and identify any unverified device behavior.
