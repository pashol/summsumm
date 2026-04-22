# Onboarding Feature Design

## Overview

A 4-screen linear wizard on first app launch that explains what works online vs offline, guides optional API key setup, and gets users to a functional state quickly. Skippable at any point.

## Architecture

**Trigger**: Onboarding shows on first launch if `hasCompletedOnboarding` flag is `false` in `SharedPreferences`. Checked after `SettingsProvider.load()` in `main()`.

**Navigation**: `OnboardingScreen` is a full-screen route pushed before the existing intent-routing logic. Uses `PageView` with 4 pages.

**State**: Simple `OnboardingState` managed by the screen's `State` class (not Riverpod -- too ephemeral). Tracks:
- Current page index
- Selected provider (OpenRouter/OpenAI)
- API key input
- Whether user skipped API key setup

**Completion**: Sets `hasCompletedOnboarding = true` in `SharedPreferences`, then routes based on intent (same as current `main()` logic).

**Skip behavior**: "Skip" button on any page jumps to page 4 (Quick Start) with API key marked as skipped. User can configure later in Settings.

## Screen Flow

### Screen 1 -- Welcome
- Large app icon/illustration at top
- Headline: "Summarize Anything, Anywhere"
- Subtitle: "AI-powered summaries from text, voice, and documents"
- "Get Started" button (primary, full-width)
- "Skip Setup" text button at bottom

### Screen 2 -- Feature Overview
- Two visual cards:
  - **Online Features** (cloud icon): Text summarization, PDF summaries, cloud transcription -- "Requires API key"
  - **Offline Features** (phone icon): Meeting recording, on-device transcription -- "Works without internet after model download"
- Note: "On-device transcription supports multiple languages. Live transcription works best with English."
- "Continue" button

### Screen 3 -- API Key Setup
- Provider dropdown (OpenRouter / OpenAI), same as Settings
- API key input with show/hide toggle
- "Test Connection" button (same logic as Settings, uses `AiService.testConnection()`)
- "Skip for Now" text button (prominently placed)
- Visual indicator: green checkmark if connection succeeds

### Screen 4 -- Quick Start
- Summary of configured state:
  - "You're ready to summarize text and PDFs" (if API key configured)
  - OR "You can record meetings and use on-device transcription" (if skipped)
- "Get Started" button (completes onboarding)
- "Go to Settings" link for further configuration

## Components & Integration

**New files:**
- `lib/screens/onboarding_screen.dart` -- Main onboarding wizard widget
- Localization strings added to existing `.arb` files

**No new providers or services.** Uses existing `SettingsProvider` and `SecureStorageService` for API key setup. Uses `SharedPreferences` directly for the `hasCompletedOnboarding` flag.

**Reusing existing logic:**
- Provider dropdown and API key input follow the same patterns as `SettingsScreen`
- "Test Connection" reuses `AiService.testConnection()` directly
- Onboarding is self-contained -- not extracting shared widgets since it's shown once

**Integration with `main()`:**
- After `SettingsProvider.load()`, check `hasCompletedOnboarding`
- If `false`, push `OnboardingScreen` as full-screen route
- On completion, set flag and proceed with existing intent routing

**Localization:** All strings through `AppLocalizations` (existing `.arb` files). New keys for each screen's title, subtitle, button labels, and feature descriptions.

**Error handling:**
- API key test failure shows inline error (same pattern as Settings)
- No network on first launch is fine -- user can skip and configure later
