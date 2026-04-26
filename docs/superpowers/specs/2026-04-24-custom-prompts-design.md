# Custom Prompts for Meeting Summaries — Design Spec

**Date:** 2026-04-24
**Feature:** Allow users to edit built-in summary prompts and add custom prompts for meeting/document summaries.

---

## 1. Goal

Users want control over how AI generates summaries. Currently, 4 hardcoded styles exist (concise, brief, detailed, structured). This feature enables:
- Editing any built-in prompt and resetting to defaults
- Creating unlimited custom named prompts
- All prompts appearing in the same Summary Style dropdown

---

## 2. Data Model

### 2.1 AppSettings Additions

```dart
class AppSettings {
  // ... existing fields ...
  
  /// User overrides for built-in summary prompts.
  /// Key: style name ('concise', 'brief', 'detailed', 'structured')
  /// Value: custom prompt text (without langSuffix)
  final Map<String, String> promptOverrides;
  
  /// User-created custom prompts.
  final List<CustomPrompt> customPrompts;
  
  const AppSettings({
    // ... existing params ...
    this.promptOverrides = const {},
    this.customPrompts = const [],
  });
}
```

### 2.2 CustomPrompt Model

```dart
class CustomPrompt {
  final String id;      // UUID v4
  final String name;    // User-defined display label
  final String text;    // Prompt content (without langSuffix)
  
  const CustomPrompt({
    required this.id,
    required this.name,
    required this.text,
  });
  
  factory CustomPrompt.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
  CustomPrompt copyWith({String? name, String? text}) => ...
}
```

### 2.3 Prompt Resolution

```dart
String resolvePrompt(SummaryStyle? style, CustomPrompt? custom, AppSettings settings) {
  if (custom != null) return custom.text + _langSuffix;
  if (style != null && settings.promptOverrides.containsKey(style.name)) {
    return settings.promptOverrides[style.name]! + _langSuffix;
  }
  return _defaultPrompt(style) + _langSuffix;
}
```

**Key rule:** The `langSuffix` (language instruction) is always auto-appended. Users never see or edit it.

---

## 3. UI/UX

### 3.1 Settings Row

Rename "Summary & Language" → **"Summary"** in `SettingsScreen`.

### 3.2 Prompt Editor Screen

New screen: `lib/screens/settings/prompt_editor_screen.dart`

**Layout:**
```
┌─────────────────────────────┐
│ ← Summary Prompts           │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ Default Prompt          │ │
│ │ [concise ▼]             │ │
│ │                         │ │
│ │ [TextField              │ │
│ │  multiline, 8 lines]    │ │
│ │                         │ │
│ │ [↺ Reset to default]    │ │
│ └─────────────────────────┘ │
│                             │
│ Custom Prompts              │
│ ┌─────────────────────────┐ │
│ │ 📝 Executive Summary    │ │
│ │    Summarize for...     │ │
│ │    [✏️] [🗑️]            │ │
│ ├─────────────────────────┤ │
│ │ 📝 Bullet Points        │ │
│ │    List the main...     │ │
│ │    [✏️] [🗑️]            │ │
│ └─────────────────────────┘ │
│                             │
│     [+  FAB]                │
└─────────────────────────────┘
```

**Components:**
- **Style dropdown**: Switch between built-in styles. On change, load override text or default.
- **Text editor**: `TextField(maxLines: 8)`. Auto-saves debounced (300ms after typing stops).
- **Reset button**: Only visible for built-in styles. Removes override from `promptOverrides`.
- **Custom prompts list**: Expandable cards showing name + preview. Edit opens bottom sheet. Delete shows confirmation dialog.
- **FAB**: Opens bottom sheet to create new custom prompt (name + text fields).

### 3.3 Bottom Sheet — Add/Edit Custom Prompt

```
┌─────────────────────────────┐
│ New Custom Prompt     [✕]   │
├─────────────────────────────┤
│ Name:                       │
│ [________________]          │
│                             │
│ Prompt text:                │
│ [                      ]    │
│ [                      ]    │
│ [                      ]    │
│                             │
│          [Cancel] [Save]    │
└─────────────────────────────┘
```

---

## 4. Data Flow

### 4.1 Editing Built-in Prompt

1. User selects style from dropdown
2. TextField shows current override or hardcoded default
3. User types → debounced save to `promptOverrides[style.name]`
4. On next summary, `resolvePrompt()` uses override

### 4.2 Resetting Built-in Prompt

1. User taps "Reset to default"
2. Remove key from `promptOverrides`
3. TextField updates to hardcoded default

### 4.3 Creating Custom Prompt

1. User taps FAB
2. Enters name + text, taps Save
3. Generate UUID, append to `customPrompts`
4. Available immediately in Summary Style dropdown

### 4.4 Deleting Custom Prompt

1. User taps delete icon
2. Confirmation dialog: "Delete 'Executive Summary'?"
3. Remove from `customPrompts`
4. If currently selected as default style, revert to 'structured'

---

## 5. Persistence

### 5.1 SharedPreferences Schema

```json
{
  "app_settings_json": {
    "promptOverrides": {
      "concise": "You are an expert..."
    },
    "customPrompts": [
      {"id": "uuid", "name": "Executive Summary", "text": "..."}
    ]
  }
}
```

### 5.2 Migration

Existing users have no `promptOverrides` or `customPrompts`. Code defaults to empty collections. Built-in prompts continue working via hardcoded fallbacks.

---

## 6. Integration Points

### 6.1 MeetingProvider

Replace `_promptForStyle()` with `PromptResolver.resolve()`:

```dart
String _promptForStyle(SummaryStyle style, MeetingType type, String langSuffixText) {
  final settings = ref.read(settingsProvider);
  final basePrompt = PromptResolver.resolve(style: style, settings: settings);
  return '$basePrompt$langSuffixText';
}
```

### 6.2 Summary Dropdown

`SummaryLanguageScreen` dropdown merges built-in + custom prompts:

```dart
DropdownButtonFormField<String>(
  items: [
    // Built-in styles
    ...SummaryStyle.values.map((s) => DropdownMenuItem(value: s.name, ...)),
    // Divider or label
    // Custom prompts
    ...settings.customPrompts.map((p) => DropdownMenuItem(value: 'custom:${p.id}', ...)),
  ],
)
```

**Value format:** Built-ins use style name (`'concise'`). Custom prompts use prefixed ID (`'custom:uuid'`).

### 6.3 Settings Provider Methods

```dart
Future<void> setPromptOverride(String style, String text);
Future<void> resetPromptOverride(String style);
Future<String> addCustomPrompt(String name, String text); // returns id
Future<void> updateCustomPrompt(String id, {String? name, String? text});
Future<void> deleteCustomPrompt(String id);
```

---

## 7. Error Handling

- **Empty prompt text**: Disable save, show "Prompt cannot be empty"
- **Duplicate name**: Allow duplicates (user can differentiate), or show warning
- **Invalid UUID reference**: Fallback to 'structured' style
- **JSON parse error on migration**: Start with empty collections, log error

---

## 8. Testing

- Unit: `PromptResolver.resolve()` — override, default, custom
- Unit: `CustomPrompt` serialization round-trip
- Widget: Prompt editor screen — edit, reset, add, delete
- Integration: Select custom prompt → generate summary → verify prompt used

---

## 9. Open Questions

1. Should custom prompts be deletable if they're the current default style? → Yes, revert to 'structured'
2. Should we validate prompt text for common issues (e.g., asking for markdown when we want plain text)? → No, user is in control
3. Max prompt length? → 2000 chars (generous but prevents abuse)
