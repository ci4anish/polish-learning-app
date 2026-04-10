export type Bindings = {
  GEMINI_API_KEY: string;
};

export type TextBlock = {
  type: "heading" | "paragraph";
  text: string;
};

export type OcrContent = {
  detectedLanguage: string;
  blocks: TextBlock[];
};

export type UsageInfo = {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
};

export type OcrResult = {
  success: boolean;
  content?: OcrContent;
  provider: string;
  model: string;
  usage?: UsageInfo;
  error?: string;
};

export type DeclensionEntry = {
  caseName: string;
  singular: string;
  plural: string;
};

export type ExampleEntry = {
  source: string;
  target: string;
};

export type ExplainContent = {
  selectedText: string;
  translation: string;
  partOfSpeech: string;
  gender: string | null;
  grammaticalCase: string | null;
  declension: DeclensionEntry[] | null;
  examples: ExampleEntry[];
};

export type ExplainResult = {
  success: boolean;
  explanation?: ExplainContent;
  provider: string;
  model: string;
  usage?: UsageInfo;
  error?: string;
};
