"use client";

import type { Message, MessagePart } from "@/lib/api";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import ToolBlock from "./ToolBlock";

interface MessageBlockProps {
  message: Message;
  isStreaming?: boolean;
  streamingText?: string;
  streamingParts?: MessagePart[];
  onChoiceSelect?: (choice: string) => void;
}

/** Parse choice lines like `[Label] → Description` from the end of a message */
function parseChoices(text: string): { body: string; choices: { label: string; desc: string }[] } {
  const choiceRegex = /^\[(.+?)\]\s*→\s*(.+)$/gm;
  const choices: { label: string; desc: string }[] = [];
  let match: RegExpExecArray | null;
  while ((match = choiceRegex.exec(text)) !== null) {
    choices.push({ label: match[1], desc: match[2].trim() });
  }
  if (choices.length === 0) return { body: text, choices: [] };

  // Remove the choice lines and any trailing "선택지:" header from the body
  let body = text.replace(/^\[.+?\]\s*→\s*.+$/gm, "").trimEnd();
  body = body.replace(/선택지:\s*$/m, "").trimEnd();
  return { body, choices };
}

export default function MessageBlock({
  message,
  isStreaming,
  streamingText,
  streamingParts,
  onChoiceSelect,
}: MessageBlockProps) {
  const isUser = message.role === "user";
  const borderColor = isUser ? "border-l-blue-500" : "border-l-emerald-500";
  const labelColor = isUser ? "text-blue-400" : "text-emerald-400";
  const label = isUser ? "You" : "Assistant";

  // For streaming assistant messages, use streamingText; otherwise use message.content
  const textContent = isStreaming ? (streamingText ?? "") : message.content;

  // Tool parts: from streaming or from completed message
  const toolParts = isStreaming
    ? (streamingParts ?? []).filter((p) => p.type !== "text")
    : (message.parts ?? []).filter((p) => p.type !== "text");

  // Parse choices from completed assistant messages (not while streaming)
  const { body: displayText, choices } =
    !isUser && !isStreaming ? parseChoices(textContent) : { body: textContent, choices: [] };

  return (
    <div className={`border-l-2 ${borderColor} pl-3 py-2 border-b border-zinc-800`}>
      <div className={`text-xs font-semibold uppercase tracking-wide ${labelColor} mb-1`}>
        {label}
      </div>

      {/* Tool blocks */}
      {toolParts.length > 0 && (
        <div className="mb-2">
          {toolParts.map((part) => (
            <ToolBlock key={part.id} part={part} />
          ))}
        </div>
      )}

      {/* Text content */}
      {displayText && (
        isUser ? (
          <p className="text-sm text-zinc-200 whitespace-pre-wrap">{displayText}</p>
        ) : (
          <div className="prose prose-invert prose-sm max-w-none">
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{displayText}</ReactMarkdown>
            {isStreaming && <span className="animate-pulse text-zinc-400">▍</span>}
          </div>
        )
      )}

      {/* Choice buttons */}
      {choices.length > 0 && (
        <div className="mt-3 flex flex-col gap-2">
          {choices.map((choice, idx) => (
            <button
              key={idx}
              onClick={() => onChoiceSelect?.(choice.label)}
              className="flex items-center gap-3 w-full text-left px-3 py-2 rounded border border-zinc-700 bg-zinc-900 hover:bg-zinc-800 hover:border-zinc-500 transition-colors group"
            >
              <span className="flex-shrink-0 w-6 h-6 rounded bg-zinc-700 group-hover:bg-emerald-600 text-zinc-300 group-hover:text-white text-xs font-bold flex items-center justify-center transition-colors">
                {idx + 1}
              </span>
              <div className="flex flex-col">
                <span className="text-sm font-medium text-zinc-200">{choice.label}</span>
                <span className="text-xs text-zinc-500">{choice.desc}</span>
              </div>
            </button>
          ))}
        </div>
      )}

      {/* Streaming with no text yet */}
      {isStreaming && !textContent && toolParts.length === 0 && (
        <span className="text-sm animate-pulse text-zinc-400">Thinking...</span>
      )}
    </div>
  );
}
