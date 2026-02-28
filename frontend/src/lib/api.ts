/** OpenCode API client wrapper */

const BASE = "/api/opencode";
/** Direct backend URL — bypasses Next.js proxy to avoid timeout on long AI responses */
const BACKEND = "http://localhost:4096";

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
  const res = await fetch(`${BACKEND}/session/${sessionId}/message`, {
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

  // The server uses streaming response (hono stream()).
  // Read the full body as text first, then parse — res.json() fails on
  // chunked/streaming responses that arrive incrementally.
  const body = await res.text();
  if (!body) {
    throw new Error("서버에서 빈 응답을 받았습니다. AI 모델 설정을 확인해주세요.");
  }
  const raw: MessageV2WithParts = JSON.parse(body);

  // Surface server-side errors (e.g. missing API key)
  if (raw.info.error) {
    const err = raw.info.error as Record<string, unknown>;
    const data = err.data as Record<string, unknown> | undefined;
    const msg = data?.message || err.message || err.name || "서버에서 에러가 발생했습니다.";
    throw new Error(String(msg));
  }

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

// ── SSE streaming ─────────────────────────────────────────────────

export interface SSECallbacks {
  onDelta?: (text: string) => void;
  onPartUpdated?: (part: MessagePart) => void;
  /** Fired when the assistant message is complete (info only, no parts). */
  onMessageComplete?: (info: MessageV2WithParts["info"]) => void;
  onError?: (err: Error) => void;
}

/**
 * Connect to the backend SSE event stream and dispatch events for a given session.
 *
 * The backend sends all events as the default SSE "message" event (no `event:` field),
 * so we use `onmessage` and dispatch based on the `type` field inside the JSON data.
 *
 * Event structures (from message-v2.ts):
 *  - message.part.delta:   { type, properties: { sessionID, messageID, partID, field, delta } }
 *  - message.part.updated: { type, properties: { part: { sessionID, messageID, type, text?, ... } } }
 *  - message.updated:      { type, properties: { info: { id, sessionID, role, time, error? } } }
 *
 * Returns a cleanup function to close the connection.
 */
export function connectSSE(sessionId: string, callbacks: SSECallbacks): () => void {
  const es = new EventSource(`${BACKEND}/event`);

  es.onmessage = (e: MessageEvent) => {
    try {
      const data = JSON.parse(e.data);
      const type = data.type as string | undefined;
      const props = data.properties;
      if (!type || !props) return;

      switch (type) {
        case "message.part.delta": {
          if (props.sessionID !== sessionId) return;
          if (props.field === "text" && typeof props.delta === "string") {
            callbacks.onDelta?.(props.delta);
          }
          break;
        }
        case "message.part.updated": {
          const part = props.part;
          if (part?.sessionID !== sessionId) return;
          callbacks.onPartUpdated?.(part as MessagePart);
          break;
        }
        case "message.updated": {
          const info = props.info;
          if (info?.sessionID !== sessionId) return;
          callbacks.onMessageComplete?.(info);
          break;
        }
      }
    } catch { /* ignore parse errors */ }
  };

  es.onerror = () => {
    callbacks.onError?.(new Error("SSE connection error"));
  };

  return () => es.close();
}

/**
 * Fire-and-forget message send — the actual response arrives via SSE events.
 */
export async function sendMessageStreaming(
  sessionId: string,
  content: string,
): Promise<void> {
  const res = await fetch(`${BACKEND}/session/${sessionId}/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      parts: [{ type: "text", text: content }],
    }),
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    throw new Error(`Failed to send message: ${res.status} ${errText}`);
  }
  // We don't need to parse the response — SSE handles it
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
