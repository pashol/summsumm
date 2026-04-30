# Ask Library Follow-Up Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Ask Library follow-up questions preserve conversational context while keeping every answer grounded in fresh local retrieval.

**Architecture:** Keep retrieval-first chat behavior inside `AskLibraryChatNotifier`. Each turn should rebuild a compact retrieval query from the new question plus recent history, run fresh `LibraryRagRepository.search()`, then send a bounded recent-history window and the fresh retrieval context to `AiService.streamCompletion()`.

**Tech Stack:** Flutter, Dart, Riverpod, existing `AiService`, existing `LibraryRagRepository`, `flutter_test`.

---

## File Structure

- Modify: `lib/providers/ask_library_chat_provider.dart` to add bounded LLM history and retrieval-query building.
- Modify: `test/providers/ask_library_chat_provider_test.dart` to cover retrieval-first follow-up behavior.
- Verify: `test/screens/ask_library_screen_test.dart` still passes after provider changes.

---

### Task 1: Add Failing Follow-Up Provider Tests

**Files:**
- Modify: `test/providers/ask_library_chat_provider_test.dart`

- [ ] Add a failing test that sends a second Ask Library question and asserts the LLM prompt includes prior user and assistant turns.
- [ ] Run `flutter test test/providers/ask_library_chat_provider_test.dart` and confirm the new test fails because `AskLibraryChatNotifier` only sends the current turn.

### Task 2: Implement Retrieval-First Prompt Assembly

**Files:**
- Modify: `lib/providers/ask_library_chat_provider.dart`

- [ ] Add private helpers to build a bounded recent-history window and a compact retrieval query.
- [ ] Change `sendMessage()` to run retrieval on every turn using the compact retrieval query.
- [ ] Change the LLM request to include the fresh grounded context block plus recent chat history before the final user turn.
- [ ] Keep citations sourced from the current turn's retrieval result only.

### Task 3: Verify Follow-Up Grounding

**Files:**
- Modify: `test/providers/ask_library_chat_provider_test.dart`
- Verify: `test/screens/ask_library_screen_test.dart`

- [ ] Add or extend tests to prove follow-up retrieval still runs on every turn and that current-turn citations are replaced with fresh retrieval citations.
- [ ] Run `flutter test test/providers/ask_library_chat_provider_test.dart test/screens/ask_library_screen_test.dart`.
- [ ] Run `flutter analyze lib/providers/ask_library_chat_provider.dart test/providers/ask_library_chat_provider_test.dart test/screens/ask_library_screen_test.dart`.
