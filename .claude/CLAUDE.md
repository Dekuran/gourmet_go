# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

See [README.md](../README.md) for the full game description, art style, and platform details. See [docs/restaurant_sim_prototype.md](../docs/restaurant_sim_prototype.md) for the full prototype plan and [docs/todo.md](../docs/todo.md) for the hackathon build task breakdown (BE/FE).

Gourmet GO is a Flutter/Flame iOS simulation game. The project targets iOS only (android, macos, linux, web, and windows platform folders have been removed).

## Common Commands

- **Install dependencies:** `flutter pub get`
- **Run app:** `flutter run`
- **Run tests:** `flutter test`
- **Run single test:** `flutter test test/<test_file>.dart`
- **Analyze code:** `flutter analyze`
- **Format code:** `dart format .`
- **Apply fixes:** `dart fix --apply`
- **Run DCM:** `dcm analyze lib`

## Linting

- Uses `flutter_lints` (via `analysis_options.yaml`)
- DCM (Dart Code Metrics) is configured with 44 free-tier rules (34 Common + 10 Flutter) and code metrics

## Code Style

See [.claude/rules/code-style.md](rules/code-style.md) for detailed Flutter/Dart conventions covering architecture, state management, theming, testing, and more.
