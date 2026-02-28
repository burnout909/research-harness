"use client";

import { useState } from "react";
import type { MessagePart } from "@/lib/api";

interface ToolBlockProps {
  part: MessagePart;
}

function StatusIcon({ state }: { state?: string }) {
  switch (state) {
    case "running":
    case "pending":
      return (
        <svg className="w-4 h-4 animate-spin text-blue-400" viewBox="0 0 24 24" fill="none">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      );
    case "completed":
      return (
        <svg className="w-4 h-4 text-emerald-400" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
        </svg>
      );
    case "error":
      return (
        <svg className="w-4 h-4 text-red-400" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
        </svg>
      );
    default:
      return <span className="w-4 h-4 inline-block rounded-full bg-zinc-600" />;
  }
}

function getToolSummary(part: MessagePart): string {
  const name = part.name || part.type || "tool";
  const args = part.args as Record<string, unknown> | undefined;
  if (!args) return name;

  switch (name) {
    case "bash":
    case "Bash":
      return args.command ? `bash: ${String(args.command).slice(0, 80)}` : name;
    case "read":
    case "Read":
      return args.file_path ? `read: ${String(args.file_path)}` : name;
    case "write":
    case "Write":
      return args.file_path ? `write: ${String(args.file_path)}` : name;
    case "edit":
    case "Edit":
      return args.file_path ? `edit: ${String(args.file_path)}` : name;
    case "glob":
    case "Glob":
      return args.pattern ? `glob: ${String(args.pattern)}` : name;
    case "grep":
    case "Grep":
      return args.pattern ? `grep: ${String(args.pattern)}` : name;
    default:
      return name;
  }
}

export default function ToolBlock({ part }: ToolBlockProps) {
  const [open, setOpen] = useState(false);
  const summary = getToolSummary(part);

  return (
    <div className="border border-zinc-800 rounded bg-zinc-900/50 my-1.5">
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-2 px-3 py-1.5 text-left hover:bg-zinc-800/50 transition-colors"
      >
        <StatusIcon state={part.state} />
        <span className="font-mono font-medium text-zinc-300 text-xs truncate">{summary}</span>
        <svg
          className={`w-3 h-3 text-zinc-500 ml-auto transition-transform ${open ? "rotate-90" : ""}`}
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path fillRule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clipRule="evenodd" />
        </svg>
      </button>
      {open && (
        <div className="px-3 py-2 border-t border-zinc-800 overflow-x-auto">
          <pre className="text-xs text-zinc-400 font-mono whitespace-pre-wrap break-all">
            {JSON.stringify(part, null, 2)}
          </pre>
        </div>
      )}
    </div>
  );
}
