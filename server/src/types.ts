export type Bindings = {
  GEMINI_API_KEY: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

export type Variables = {
  userId: string;
};

export type TextBlock = {
  type: "heading" | "paragraph";
  original: string;
  translated: string;
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

export type TranslateContent = {
  selectedText: string;
  translation: string;
};

export type TranslateResult = {
  success: boolean;
  translation?: TranslateContent;
  provider: string;
  model: string;
  error?: string;
};

export type AudioResult = {
  success: boolean;
  audioData?: Uint8Array;
  mimeType?: string;
  error?: string;
};
