# Ask Library Follow-Up Context Design

**Date:** 2026-04-30
**Status:** Approved design

## Goal

Make Ask Library follow-up questions behave like a normal multi-turn chat while keeping every answer grounded in fresh library retrieval.

## Context

`AskLibraryChatNotifier` currently stores the visible chat history in `AskLibraryChatState.messages`, but each LLM call is sent as a fresh two-message prompt with only a system instruction and the current turn's retrieved context plus question. This means the UI shows chat history while the model does not receive it, so follow-ups like "tell me more about that" lose context.

## Chosen Approach

Use retrieval-first follow-up chat:

- Keep recent chat history in the LLM prompt so references to prior turns resolve naturally.
- Re-run local RAG retrieval on every turn so the answer stays grounded in current library sources.
- Build the retrieval query from the new user question plus a compact recent history window rather than from the new question alone.

This matches expected chat behavior while reducing hallucination risk compared with pure conversation memory.

## Architecture

Keep the change inside `AskLibraryChatNotifier`, because it already owns visible message state, streaming updates, provider access, and the LLM request assembly.

Add small private helpers inside `lib/providers/ask_library_chat_provider.dart` for:

- building a bounded recent-history window for the LLM prompt
- building a compact retrieval query from recent turns and the new question
- formatting the grounded context block that is sent alongside the current turn

No model or screen schema changes are required. `AskLibraryScreen` keeps rendering chat messages and citations exactly as it does now.

## Data Flow

For each Ask Library turn:

1. Append the user message and an empty assistant placeholder to state.
2. Build a compact retrieval query from the new question plus a small recent-history window.
3. Run `LibraryRagRepository.search(retrievalQuery)`.
4. Convert the search result into current-turn citations.
5. Build the LLM prompt using:
   - a stable system instruction
   - a grounded context block from the fresh retrieval result
   - a bounded recent-history window from chat state
   - the current user question as the final user turn
6. Stream the answer into the last assistant message.

The retrieval query and LLM history are related but not identical:

- retrieval query should be compact and optimized for search recall
- LLM history should preserve enough wording to resolve references like "that" or "the second point"

## Limits

- LLM history window: last 6 messages maximum
- Retrieval context source: current-turn search result only
- Visible UI history: unchanged, full chat remains visible

The prompt window should be bounded so long chats do not grow without limit.

## Error Handling

- If retrieval returns no context, keep the user message and replace the assistant placeholder with a grounded fallback explaining that there is not enough relevant library context for the follow-up.
- If the LLM request fails, keep the user message, remove the placeholder assistant message, and surface the existing provider error.
- If a follow-up is ambiguous, recent history should usually disambiguate it. If retrieval still cannot ground the request, prefer the existing grounded fallback over guessing.

## Citations

- Only citations from the current turn's retrieval result support the current answer.
- Do not carry old citations forward implicitly.

## Testing

Provider tests should cover:

- follow-up turns include recent conversation history in the LLM prompt
- retrieval still runs on every turn, including follow-ups
- current-turn citations come from fresh retrieval only
- retrieval queries include recent context when building follow-up searches

Widget tests should continue proving that Ask Library renders multi-turn chat and markdown responses correctly.

## Out Of Scope

- persistent Ask Library chats across app launches
- summarizing or compressing long chat history into a stored memory object
- source-level UI affordances beyond current citation chips
