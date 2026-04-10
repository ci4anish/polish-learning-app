export type Bindings = {
  GEMINI_API_KEY: string;
};

export type OcrResult = {
  success: boolean;
  text: string;
  provider: string;
  model: string;
  usage?: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
  error?: string;
};
