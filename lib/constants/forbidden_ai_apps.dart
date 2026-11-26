class ForbiddenAiApp {
  const ForbiddenAiApp({required this.displayName, required this.packageName});

  final String displayName;

  final String packageName;
}

const List<ForbiddenAiApp> kForbiddenAiApps = [
  ForbiddenAiApp(displayName: 'ChatGPT', packageName: 'com.openai.chatgpt'),
  ForbiddenAiApp(
    displayName: 'Google Gemini',
    packageName: 'com.google.android.apps.bard',
  ),
  ForbiddenAiApp(
    displayName: 'Microsoft Copilot',
    packageName: 'com.microsoft.copilot',
  ),
  ForbiddenAiApp(
    displayName: 'DeepSeek',
    packageName: 'com.deepseek.chat',
  ),
  ForbiddenAiApp(
    displayName: 'Perplexity',
    packageName: 'ai.perplexity.app.android',
  ),
  ForbiddenAiApp(
    displayName: 'Claude by Anthropic',
    packageName: 'com.anthropic.claude',
  ),
  ForbiddenAiApp(
    displayName: 'Brainly',
    packageName: 'co.brainly',
  ),
  ForbiddenAiApp(
    displayName: 'Photomath',
    packageName: 'com.photomath.android',
  ),
  ForbiddenAiApp(
    displayName: 'Question AI',
    packageName: 'com.questionai.app',
  ),
  ForbiddenAiApp(
    displayName: 'Qanda',
    packageName: 'com.mathpresso.qanda',
  ),
  ForbiddenAiApp(
    displayName: 'Gauth (Gauthmath)',
    packageName: 'com.gauthmath',
  ),
  ForbiddenAiApp(
    displayName: 'Mathway',
    packageName: 'com.bagatrix.mathway.android',
  ),
  ForbiddenAiApp(
    displayName: 'Socratic by Google',
    packageName: 'com.google.socratic',
  ),
];
