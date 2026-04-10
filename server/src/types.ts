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

export type OcrResult = {
  success: boolean;
  content?: OcrContent;
  provider: string;
  model: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  error?: string;
};
