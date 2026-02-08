# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

benchmark-sweet is a Ruby gem that runs multiple kinds of benchmarks (IPS, memory, database queries) on a common set of code and generates comparison tables. Results can be saved/loaded from JSON for cross-version comparisons.

## Commands

```bash
bundle exec rake spec        # Run tests (RSpec, default rake task)
bundle exec rake install     # Install gem locally
bundle exec rake release     # Release to RubyGems
```

## Architecture

- **`Benchmark::Sweet`** module (lib/benchmark/sweet.rb) — entry point, table rendering, extends `Benchmark`
- **`Job`** (job.rb) — central orchestrator, mixes in `IPS`, `Memory`, `Queries` modules for each metric type
- **`Item`** (item.rb) — wraps a single benchmark entry (label + action/block)
- **`Comparison`** (comparison.rb) — wraps a result with slowdown/overlap stats and display formatting
- **Metric modules** — `IPS` (ips.rb), `Memory` (memory.rb), `Queries` (queries.rb) are mixed into Job

Flow: `Benchmark.items` creates a `Job`, yields it for configuration, loads saved entries, runs metrics, saves entries, then generates a comparison report via `comparison_values` → `table`.

Labels are Hashes (not strings), enabling multi-dimensional `compare_by` and `report_with` grouping/pivoting.

## Usage

See [README.md](README.md) for full API documentation, including labels, `metadata`, `compare_by`,
`report_with`, `save_file`, cross-version comparisons, and custom value formatting.

## Dependencies

- `benchmark-ips` — IPS measurement and Stats::SD class
- `memory_profiler` — memory profiling
- `activesupport` — only used for `Hash#symbolize_keys!` in `load_entries` (marked for removal)
