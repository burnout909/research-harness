"use client";

export interface FileInfo {
  name: string;
  type: "xlsx" | "csv" | "docx" | "pdf" | "png" | "jpg" | "svg" | "unknown";
  path: string;
  size?: string;
}

interface FileCardProps {
  file: FileInfo;
  isActive: boolean;
  onClick: () => void;
}

const TYPE_ICONS: Record<string, string> = {
  xlsx: "📊",
  csv: "📋",
  docx: "📄",
  pdf: "📕",
  png: "🖼",
  jpg: "🖼",
  svg: "🖼",
  unknown: "📁",
};

export default function FileCard({ file, isActive, onClick }: FileCardProps) {
  return (
    <button
      onClick={onClick}
      className={`
        w-full text-left px-3 py-2 rounded-lg transition-colors text-sm
        ${isActive
          ? "bg-blue-600/20 border border-blue-500/50 text-blue-300"
          : "bg-zinc-800/50 border border-zinc-700/50 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
        }
      `}
    >
      <div className="flex items-center gap-2">
        <span>{TYPE_ICONS[file.type] || TYPE_ICONS.unknown}</span>
        <span className="truncate font-medium">{file.name}</span>
      </div>
      {file.size && (
        <div className="text-xs text-zinc-500 mt-0.5 pl-6">{file.size}</div>
      )}
    </button>
  );
}
