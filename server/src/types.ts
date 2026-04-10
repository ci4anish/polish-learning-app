export type Bindings = {
  DEEPINFRA_API_KEY: string;
  NOVITA_API_KEY: string;
  PROVIDER_ORDER: string;
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
