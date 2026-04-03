const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta";

export async function askGemini(prompt: string): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY ?? "";

  if (!apiKey) {
    return "⚠️ Gemini API key not configured. Add GEMINI_API_KEY to your .env file.";
  }

  const url = `${GEMINI_API_BASE}/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1024,
      },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    console.error("Gemini API error:", errText);
    return "Sorry, I couldn't process that request right now. Please try again.";
  }

  const data = await res.json();
  const text =
    data?.candidates?.[0]?.content?.parts?.[0]?.text ??
    "I didn't get a response. Try rephrasing your question.";

  return text;
}
