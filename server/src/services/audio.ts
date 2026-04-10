import type { Bindings, AudioResult } from "../types";

const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
const GEMINI_TTS_MODEL = "gemini-2.5-flash-preview-tts";

function buildWavHeader(pcmLength: number, sampleRate = 24000, channels = 1, bitDepth = 16): Uint8Array {
  const header = new ArrayBuffer(44);
  const view = new DataView(header);
  const byteRate = sampleRate * channels * (bitDepth / 8);
  const blockAlign = channels * (bitDepth / 8);

  view.setUint32(0, 0x52494646, false);       // "RIFF"
  view.setUint32(4, 36 + pcmLength, true);    // file size - 8
  view.setUint32(8, 0x57415645, false);       // "WAVE"
  view.setUint32(12, 0x666d7420, false);      // "fmt "
  view.setUint32(16, 16, true);               // fmt chunk size
  view.setUint16(20, 1, true);                // PCM format
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitDepth, true);
  view.setUint32(36, 0x64617461, false);      // "data"
  view.setUint32(40, pcmLength, true);

  return new Uint8Array(header);
}

type GeminiTTSResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        inlineData?: { data: string; mimeType: string };
      }>;
    };
  }>;
};

export async function performTTS(text: string, env: Bindings, language?: string): Promise<AudioResult> {
  if (!env.GEMINI_API_KEY) {
    return { success: false, error: "GEMINI_API_KEY is not configured" };
  }

  try {
    const response = await fetch(
      `${GEMINI_BASE_URL}/models/${GEMINI_TTS_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `Read aloud: "${text}"` }] }],
          generationConfig: {
            responseModalities: ["AUDIO"],
            speechConfig: {
              voiceConfig: {
                prebuiltVoiceConfig: { voiceName: "Kore" },
              },
            },
          },
        }),
      },
    );

    if (!response.ok) {
      const errText = await response.text();
      return { success: false, error: `Gemini TTS error ${response.status}: ${errText}` };
    }

    const json = await response.json() as GeminiTTSResponse;
    const inlineData = json.candidates?.[0]?.content?.parts?.[0]?.inlineData;

    if (!inlineData?.data) {
      return { success: false, error: "No audio data returned from Gemini TTS" };
    }

    const binaryStr = atob(inlineData.data);
    const pcmBytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      pcmBytes[i] = binaryStr.charCodeAt(i);
    }

    const rateMatch = inlineData.mimeType.match(/rate=(\d+)/);
    const sampleRate = rateMatch ? parseInt(rateMatch[1], 10) : 24000;

    const wavHeader = buildWavHeader(pcmBytes.length, sampleRate);
    const wav = new Uint8Array(wavHeader.length + pcmBytes.length);
    wav.set(wavHeader, 0);
    wav.set(pcmBytes, wavHeader.length);

    return { success: true, audioData: wav, mimeType: "audio/wav" };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("[audio] gemini TTS failed:", message);
    return { success: false, error: message };
  }
}
