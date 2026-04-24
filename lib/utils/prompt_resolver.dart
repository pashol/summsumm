import '../models/app_settings.dart';
import '../models/custom_prompt.dart';
import '../models/summary_style.dart';

class PromptResolver {
  static String resolve({
    SummaryStyle? style,
    CustomPrompt? customPrompt,
    required AppSettings settings,
  }) {
    if (customPrompt != null) {
      return customPrompt.text;
    }

    if (style != null && settings.promptOverrides.containsKey(style.name)) {
      return settings.promptOverrides[style.name]!;
    }

    return _defaultPrompt(style ?? SummaryStyle.structured);
  }

  static String _defaultPrompt(SummaryStyle style) {
    switch (style) {
      case SummaryStyle.concise:
        return 'You are an expert summarizer. Produce a brief summary with 3-5 bullet points covering only the key points. Do not elaborate. Do not wrap output in a code block.';
      case SummaryStyle.brief:
        return 'You are an expert document summarizer. Write a short paragraph summarizing the key points of this document. Do not use bullet points or headers. Do not wrap output in a code block.';
      case SummaryStyle.detailed:
        return 'You are an expert summarizer. Produce a comprehensive summary with thorough coverage of each topic. Include context and reasoning. Use ## headers for topics, paragraphs for detail. Do not wrap output in a code block.';
      case SummaryStyle.structured:
        return 'You are an expert meeting summarizer. Extract: 1. Key decisions made 2. Action items with owners 3. Open questions 4. Important context. Use markdown headers and bullet points. Do not wrap output in a code block. Be concise and factual.';
    }
  }
}
