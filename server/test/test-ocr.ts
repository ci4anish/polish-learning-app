import fs from "node:fs";
import path from "node:path";
import { v4 as uuidv4 } from "uuid";

const BASE_URL = process.env.API_URL ?? "http://localhost:8787";
const DEFAULT_IMAGE = path.join(__dirname, "fixtures", "sample-page.jpg");

async function main() {
  const imagePath = process.argv[2] ?? DEFAULT_IMAGE;

  if (!fs.existsSync(imagePath)) {
    console.error(`Image not found: ${imagePath}`);
    console.error(
      "Place a book page image at test/fixtures/sample-page.jpg or pass a path as argument.",
    );
    process.exit(1);
  }

  const imageBuffer = fs.readFileSync(imagePath);
  const base64 = imageBuffer.toString("base64");
  const ext = path.extname(imagePath).slice(1) || "jpeg";
  const mimeType = ext === "jpg" ? "image/jpeg" : `image/${ext}`;
  const dataUrl = `data:${mimeType};base64,${base64}`;

  console.log(`Sending image: ${imagePath} (${(imageBuffer.length / 1024).toFixed(1)} KB)`);
  console.log(`Target: ${BASE_URL}/api/ocr`);

  const start = Date.now();

  const response = await fetch(`${BASE_URL}/api/ocr`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ image: dataUrl }),
  });

  const elapsed = ((Date.now() - start) / 1000).toFixed(2);
  const result = await response.json();

  console.log(`\nResponse (${elapsed}s):`);
  console.log(`  Status: ${response.status}`);
  console.log(`  Provider: ${result.provider || "N/A"}`);
  console.log(`  Model: ${result.model || "N/A"}`);
  console.log(`  Success: ${result.success}`);

  if (result.usage) {
    console.log(
      `  Tokens: ${result.usage.prompt_tokens} prompt + ${result.usage.completion_tokens} completion = ${result.usage.total_tokens} total`,
    );
  }

  if (result.error) {
    console.log(`  Error: ${result.error}`);
  }

  const runId = uuidv4();
  const resultsDir = path.join(__dirname, "results", runId);
  fs.mkdirSync(resultsDir, { recursive: true });

  const outputPath = path.join(resultsDir, "result.json");
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  console.log(`\nResult saved to: ${outputPath}`);

  if (result.text) {
    const textPath = path.join(resultsDir, "extracted-text.txt");
    fs.writeFileSync(textPath, result.text);
    console.log(`Extracted text saved to: ${textPath}`);

    console.log(`\n--- Extracted text (first 500 chars) ---`);
    console.log(result.text.slice(0, 500));
    if (result.text.length > 500) console.log("...");
  }
}

main().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
