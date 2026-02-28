/** OpenCode API client wrapper */

const BASE = "/api/opencode";

// ── Types matching OpenCode server ─────────────────────────────────

export interface Session {
  id: string;
  slug: string;
  title: string;
  projectID: string;
  directory: string;
  version: string;
  time: {
    created: number;
    updated: number;
  };
}

/** Display-level message used by the chat UI */
export interface Message {
  id?: string;
  role: "user" | "assistant";
  content: string;
}

export interface MessagePart {
  id: string;
  type: string;
  text?: string;
  [key: string]: unknown;
}

export interface MessageV2WithParts {
  info: {
    id: string;
    sessionID: string;
    role: "user" | "assistant";
    time: { created: number; completed?: number };
    error?: { message: string };
  };
  parts: MessagePart[];
}

// ── Session management ─────────────────────────────────────────────

export async function createSession(): Promise<Session> {
  const res = await fetch(`${BASE}/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  if (!res.ok) throw new Error(`Failed to create session: ${res.status}`);
  return res.json();
}

export async function listSessions(): Promise<Session[]> {
  const res = await fetch(`${BASE}/session`);
  if (!res.ok) throw new Error(`Failed to list sessions: ${res.status}`);
  return res.json();
}

// ── Messaging ──────────────────────────────────────────────────────

/**
 * Send a message to a session.
 * Returns the parsed assistant response with extracted text.
 */
export async function sendMessage(
  sessionId: string,
  content: string,
  opts: {
    signal?: AbortSignal;
  } = {},
): Promise<{ text: string; raw: MessageV2WithParts }> {
  const res = await fetch(`${BASE}/session/${sessionId}/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      parts: [{ type: "text", text: content }],
    }),
    signal: opts.signal,
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    throw new Error(`Failed to send message: ${res.status} ${errText}`);
  }

  const raw: MessageV2WithParts = await res.json();
  const text = extractTextFromParts(raw);

  return { text, raw };
}

/** Extract text content from parts */
function extractTextFromParts(msg: MessageV2WithParts): string {
  if (!msg?.parts) return "";
  return msg.parts
    .filter((p) => p.type === "text" && p.text)
    .map((p) => p.text!)
    .join("\n");
}

// ── Get session messages ───────────────────────────────────────────

export async function getSessionMessages(sessionId: string): Promise<Message[]> {
  const res = await fetch(`${BASE}/session/${sessionId}/message`);
  if (!res.ok) throw new Error(`Failed to get messages: ${res.status}`);
  const data: MessageV2WithParts[] = await res.json();
  return data.map((m) => ({
    id: m.info.id,
    role: m.info.role,
    content: extractTextFromParts(m) || (m.info.error?.message ?? ""),
  }));
}
