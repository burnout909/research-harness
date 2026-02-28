"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Message, MessagePart } from "@/lib/api";
import { createSession, sendMessageStreaming, connectSSE } from "@/lib/api";
import MessageBlock from "./MessageBlock";
import SplitToggle, { type SplitMode } from "../layout/SplitToggle";
import { type FileInfo } from "../viewer/FileCard";

// Map of file-creating tool names → the arg key that holds the output path
const FILE_TOOL_MAP: Record<string, string> = {
  write_excel: "file_path",
  write_docx: "file_path",
  create_plot: "output_path",
  convert_mat_to_excel: "output_path",
  generate_manuscript: "output_path",
};

/** Convert a disk path like "data/outputs/result.xlsx" to an API path */
function diskPathToApiPath(diskPath: string): string {
  // Strip leading "./" or absolute path prefixes, normalise to "data/..."
  let p = diskPath.replace(/\\/g, "/");
  const idx = p.indexOf("data/");
  if (idx >= 0) p = p.slice(idx); // "data/outputs/result.xlsx"
  return `/api/${p}`;
}

function getFileType(name: string): FileInfo["type"] {
  const ext = name.split(".").pop()?.toLowerCase();
  const map: Record<string, FileInfo["type"]> = {
    xlsx: "xlsx", xls: "xlsx", csv: "csv",
    docx: "docx", doc: "docx",
    pdf: "pdf",
    png: "png", jpg: "jpg", jpeg: "jpg", svg: "svg",
  };
  return map[ext || ""] || "unknown";
}

interface ChatWindowProps {
  splitMode: SplitMode;
  onToggleSplit: () => void;
  uploadedFiles: FileInfo[];
  onFileCreated?: (file: FileInfo) => void;
}

export default function ChatWindow({ splitMode, onToggleSplit, uploadedFiles, onFileCreated }: ChatWindowProps) {
  const [messages, setMessages] = useState<Message[]>([
    { role: "assistant", content: "Welcome to Research Harness. How can I help you today?" },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [streamingText, setStreamingText] = useState("");
  const [streamingParts, setStreamingParts] = useState<MessagePart[]>([]);
  const scrollRef = useRef<HTMLDivElement>(null);
  const streamingTextRef = useRef("");
  const streamingPartsRef = useRef<MessagePart[]>([]);
  const processedMsgIds = useRef(new Set<string>());
  const processedFilePartIds = useRef(new Set<string>());
  const sendingRef = useRef(false);

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

  // Connect SSE when session is ready
  useEffect(() => {
    if (!sessionId) return;

    const cleanup = connectSSE(sessionId, {
      onDelta: (delta) => {
        setStreamingText((prev) => {
          const next = prev + delta;
          streamingTextRef.current = next;
          return next;
        });
        scrollToBottom();
      },
      onPartUpdated: (part) => {
        setStreamingParts((prev) => {
          const idx = prev.findIndex((p) => p.id === part.id);
          const next = idx >= 0
            ? prev.map((p, i) => (i === idx ? part : p))
            : [...prev, part];
          streamingPartsRef.current = next;
          return next;
        });

        // Detect completed file-creation tools
        // SSE structure: { type: "tool", tool: "research-harness_write_excel",
        //   state: { status: "completed", input: { file_path: "..." } } }
        const toolState = part.state as { status?: string; input?: Record<string, unknown> } | undefined;
        const toolName = (part.tool as string) || "";
        // Match tool name: "research-harness_write_excel" ends with "write_excel"
        const matchedTool = Object.keys(FILE_TOOL_MAP).find((k) => toolName.endsWith(k));

        if (
          toolState?.status === "completed" &&
          matchedTool &&
          !processedFilePartIds.current.has(part.id)
        ) {
          processedFilePartIds.current.add(part.id);
          const argKey = FILE_TOOL_MAP[matchedTool];
          const diskPath = toolState.input?.[argKey] as string | undefined;
          if (diskPath) {
            const fileName = diskPath.split("/").pop() || diskPath;
            const apiPath = diskPathToApiPath(diskPath);
            setTimeout(() => {
              onFileCreated?.({
                name: fileName,
                type: getFileType(fileName),
                path: apiPath,
              });
            }, 500);
          }
        }

        scrollToBottom();
      },
      onMessageComplete: (info) => {
        console.log("[SSE] message.updated:", JSON.stringify(info));
        if (info.role !== "assistant" || !info.time.completed) return;
        if (processedMsgIds.current.has(info.id)) return;
        processedMsgIds.current.add(info.id);

        const currentText = streamingTextRef.current;
        const currentParts = streamingPartsRef.current;

        if (currentText || currentParts.length > 0) {
          setMessages((prev) => {
            if (prev.some((msg) => msg.id === info.id)) return prev;
            return [
              ...prev,
              {
                id: info.id,
                role: "assistant",
                content: currentText,
                parts: currentParts.length > 0 ? currentParts : undefined,
              },
            ];
          });
        }

        streamingTextRef.current = "";
        streamingPartsRef.current = [];
        setStreamingText("");
        setStreamingParts([]);
        sendingRef.current = false;
        setLoading(false);
        scrollToBottom();
      },
      onError: (err) => {
        console.error("SSE error:", err);
      },
    });

    return cleanup;
  }, [sessionId, scrollToBottom, onFileCreated]);

  const handleSend = useCallback(async () => {
    const text = input.trim();
    if (!text || loading || sendingRef.current) return;

    if (!sessionId) {
      setMessages((prev) => [
        ...prev,
        { role: "user", content: text },
        { role: "assistant", content: "세션이 아직 생성되지 않았습니다. OpenCode 서버 연결을 확인해주세요." },
      ]);
      setInput("");
      return;
    }

    sendingRef.current = true;
    const userMsg: Message = { role: "user", content: text };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    streamingTextRef.current = "";
    streamingPartsRef.current = [];
    setStreamingText("");
    setStreamingParts([]);
    setLoading(true);
    scrollToBottom();

    // Prepend uploaded file context so the AI agent knows file paths
    let messageToSend = text;
    if (uploadedFiles.length > 0) {
      const fileLines = uploadedFiles
        .filter((f) => f.diskPath)
        .map((f) => `- ${f.name} (경로: ${f.diskPath})`);
      if (fileLines.length > 0) {
        messageToSend = `[업로드된 파일]\n${fileLines.join("\n")}\n\n${text}`;
      }
    }

    try {
      await sendMessageStreaming(sessionId, messageToSend);
    } catch (err) {
      console.error("Send failed:", err);
      sendingRef.current = false;
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: `메시지 전송 실패: ${(err as Error).message}` },
      ]);
      setLoading(false);
    }
  }, [input, loading, sessionId, scrollToBottom, uploadedFiles]);

  const handleChoiceSelect = useCallback((choice: string) => {
    if (loading || sendingRef.current || !sessionId) return;

    sendingRef.current = true;
    const userMsg: Message = { role: "user", content: choice };
    setMessages((prev) => [...prev, userMsg]);
    streamingTextRef.current = "";
    streamingPartsRef.current = [];
    setStreamingText("");
    setStreamingParts([]);
    setLoading(true);
    scrollToBottom();

    sendMessageStreaming(sessionId, choice).catch((err) => {
      console.error("Send failed:", err);
      sendingRef.current = false;
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: `메시지 전송 실패: ${(err as Error).message}` },
      ]);
      setLoading(false);
    });
  }, [loading, sessionId, scrollToBottom]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.nativeEvent.isComposing) return;
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="flex flex-col h-full bg-zinc-950">
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
          <MessageBlock key={msg.id ?? i} message={msg} onChoiceSelect={handleChoiceSelect} />
        ))}
        {loading && (
          <MessageBlock
            message={{ role: "assistant", content: "" }}
            isStreaming
            streamingText={streamingText}
            streamingParts={streamingParts}
          />
        )}
      </div>

      {/* Input */}
      <div className="border-t border-zinc-800 p-3 flex-shrink-0">
        <textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type a message... (Enter to send, Shift+Enter for newline)"
          rows={1}
          className="w-full bg-zinc-950 border border-zinc-800 rounded px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 font-mono resize-none focus:outline-none focus:border-zinc-600 transition-colors"
        />
      </div>
    </div>
  );
}
