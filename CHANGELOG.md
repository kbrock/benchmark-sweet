# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-02-07

### Added
- Tests for Comparison, Job, Item, and table rendering

### Changed
- Removed activesupport runtime dependency (label values normalized to strings automatically)
- Loosened dependency pins for benchmark-ips (~> 2.8) and memory_profiler (~> 0.9)
- Improved README with single-example walkthrough showing how report_with reshapes output

### Fixed
- Fixed @instance typo in QueryCounter#callback (was crashing on cached queries)
- Fixed table rendering crash when header is wider than values
- Fixed table column alignment with ANSI color codes
- Properly indent tables with ANSI color codes (thanks @d-m-u)
- Removed dead code (labels_have_symbols!, unused symbol_value check)

## [0.2.1] - 2020-06-24

### Fixed
- support increase of infinity

## [0.2.0] - 2020-05-11

### Added

- changelog
- docs

### Fixed

- better color support
- updated benchmark-ips and no longer need to monkey patch for it.
- require benchmark-sweet now works
- documentation fixes (thanks @d-m-u)
- example fixes


## 0.0.1 - 2014-05-31
### Added
- good stuff

[Unreleased]: https://github.com/kbrock/benchmark-sweet/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kbrock/benchmark-sweet/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/kbrock/benchmark-sweet/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/kbrock/benchmark-sweet/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/kbrock/benchmark-sweet/compare/v0.0.1...v0.2.0
