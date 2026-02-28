"use client";

export type SplitMode = "horizontal" | "vertical";

interface SplitToggleProps {
  mode: SplitMode;
  onToggle: () => void;
}

export default function SplitToggle({ mode, onToggle }: SplitToggleProps) {
  return (
    <button
      onClick={onToggle}
      title={mode === "horizontal" ? "Switch to vertical split" : "Switch to horizontal split"}
      className="p-1 rounded hover:bg-zinc-700 transition-colors text-zinc-400 hover:text-zinc-200"
    >
      {mode === "horizontal" ? (
        // Horizontal split icon (columns side by side)
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
          <rect x="1" y="1" width="14" height="14" rx="1" />
          <line x1="8" y1="1" x2="8" y2="15" />
        </svg>
      ) : (
        // Vertical split icon (rows stacked)
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
          <rect x="1" y="1" width="14" height="14" rx="1" />
          <line x1="1" y1="8" x2="15" y2="8" />
        </svg>
      )}
    </button>
  );
}
