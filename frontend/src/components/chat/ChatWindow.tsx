"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Message } from "@/lib/api";
import { createSession, sendMessage } from "@/lib/api";
import MessageBubble from "./MessageBubble";
import SplitToggle, { type SplitMode } from "../layout/SplitToggle";

interface ChatWindowProps {
  splitMode: SplitMode;
  onToggleSplit: () => void;
}

export default function ChatWindow({ splitMode, onToggleSplit }: ChatWindowProps) {
  const [messages, setMessages] = useState<Message[]>([
    { role: "assistant", content: "Welcome to Research Harness. How can I help you today?" },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<AbortController | null>(null);

  const scrollToBottom = useCallback(() => {
    setTimeout(() => {
      scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
    }, 50);
  }, []);

  // Create a session on mount
  useEffect(() => {
    let cancelled = false;
    const init = async () => {
      try {
        const session = await createSession();
        if (!cancelled) setSessionId(session.id);
      } catch (err) {
        console.error("Failed to create session:", err);
        if (!cancelled) {
          setMessages((prev) => [
            ...prev,
            {
              role: "assistant",
              content:
                "OpenCode 서버에 연결할 수 없습니다. `opencode serve` 명령으로 서버가 실행 중인지 확인해주세요. (port 4096)",
            },
          ]);
        }
      }
    };
    init();
    return () => { cancelled = true; };
  }, []);

  const handleSend = useCallback(async () => {
    const text = input.trim();
    if (!text || loading) return;

    if (!sessionId) {
      setMessages((prev) => [
        ...prev,
        { role: "user", content: text },
        { role: "assistant", content: "세션이 아직 생성되지 않았습니다. OpenCode 서버 연결을 확인해주세요." },
      ]);
      setInput("");
      return;
    }

    const userMsg: Message = { role: "user", content: text };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setLoading(true);
    scrollToBottom();

    const abort = new AbortController();
    abortRef.current = abort;

    try {
      const { text: replyText } = await sendMessage(sessionId, text, { signal: abort.signal });
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: replyText || "(No response)" },
      ]);
    } catch (err) {
      if ((err as Error).name !== "AbortError") {
        console.error("Send failed:", err);
        setMessages((prev) => [
          ...prev,
          { role: "assistant", content: `메시지 전송 실패: ${(err as Error).message}` },
        ]);
      }
    } finally {
      setLoading(false);
      abortRef.current = null;
      scrollToBottom();
    }
  }, [input, loading, sessionId, scrollToBottom]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex flex-col h-full bg-zinc-900">
      {/* Title bar */}
      <div className="flex items-center justify-between px-4 py-2 border-b border-zinc-800 flex-shrink-0">
        <div className="flex items-center gap-2">
          <h2 className="text-sm font-medium text-zinc-300">Agent Chat</h2>
          {sessionId ? (
            <span className="w-2 h-2 rounded-full bg-green-500" title="Connected" />
          ) : (
            <span className="w-2 h-2 rounded-full bg-red-500" title="Disconnected" />
          )}
        </div>
        <SplitToggle mode={splitMode} onToggle={onToggleSplit} />
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-4 py-3">
        {messages.map((msg, i) => (
          <MessageBubble key={i} message={msg} />
        ))}
        {loading && (
          <div className="flex justify-start mb-3">
            <div className="bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-400">
              <span className="animate-pulse">Thinking...</span>
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="border-t border-zinc-800 p-3 flex-shrink-0">
        <div className="flex gap-2">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Type a message... (Enter to send, Shift+Enter for newline)"
            rows={1}
            className="flex-1 bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 resize-none focus:outline-none focus:border-blue-500 transition-colors"
          />
          <button
            onClick={handleSend}
            disabled={loading || !input.trim()}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:bg-zinc-700 disabled:text-zinc-500 text-white text-sm rounded-lg transition-colors"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
