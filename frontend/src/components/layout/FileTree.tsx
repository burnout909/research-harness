"use client";

import { useState, useEffect, useCallback } from "react";
import { type FileInfo } from "@/components/viewer/FileCard";

interface FileEntry {
  name: string;
  relativePath: string;
  size: number;
  isDirectory: boolean;
}

interface TreeNode {
  name: string;
  relativePath: string;
  isDirectory: boolean;
  size: number;
  children: TreeNode[];
}

interface FileTreeProps {
  onFileSelect: (file: FileInfo) => void;
  refreshTrigger?: number;
}

const DISPLAY_NAMES: Record<string, string> = {
  outputs: "result",
};

// Strip timestamp prefix from uploaded filenames (e.g. "1709012345_report.xlsx" → "report.xlsx")
function stripTimestampPrefix(name: string, relativePath: string): string {
  if (relativePath.startsWith("uploads/")) {
    return name.replace(/^\d+_/, "");
  }
  return name;
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

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function buildTree(entries: FileEntry[]): TreeNode[] {
  const root: TreeNode[] = [];
  const map = new Map<string, TreeNode>();

  // Sort so directories come first, then alphabetically
  const sorted = [...entries].sort((a, b) => {
    if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.relativePath.localeCompare(b.relativePath);
  });

  for (const entry of sorted) {
    // Rename top-level directories for display, strip timestamp from uploads
    const isTopLevel = !entry.relativePath.includes("/");
    const displayName = (isTopLevel && DISPLAY_NAMES[entry.name])
      || stripTimestampPrefix(entry.name, entry.relativePath);

    const node: TreeNode = {
      name: displayName,
      relativePath: entry.relativePath,
      isDirectory: entry.isDirectory,
      size: entry.size,
      children: [],
    };
    map.set(entry.relativePath, node);

    const parts = entry.relativePath.split("/");
    if (parts.length === 1) {
      root.push(node);
    } else {
      const parentPath = parts.slice(0, -1).join("/");
      const parent = map.get(parentPath);
      if (parent) {
        parent.children.push(node);
      } else {
        root.push(node);
      }
    }
  }

  return root;
}

function FileIcon({ name }: { name: string }) {
  const ext = name.split(".").pop()?.toLowerCase() || "";
  const colors: Record<string, string> = {
    xlsx: "text-green-500", xls: "text-green-500", csv: "text-green-400",
    docx: "text-blue-500", doc: "text-blue-500",
    pdf: "text-red-500",
    png: "text-purple-400", jpg: "text-purple-400", jpeg: "text-purple-400", svg: "text-purple-400",
    mat: "text-orange-400", m: "text-orange-400",
    txt: "text-zinc-400", json: "text-yellow-400",
  };
  const color = colors[ext] || "text-zinc-500";

  return (
    <svg className={`flex-shrink-0 ${color}`} width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}

function FolderIcon({ open }: { open: boolean }) {
  return open ? (
    <svg className="flex-shrink-0 text-zinc-400" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z" />
    </svg>
  ) : (
    <svg className="flex-shrink-0 text-zinc-500" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
      <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z" />
    </svg>
  );
}

function ChevronIcon({ open }: { open: boolean }) {
  return (
    <svg
      className={`flex-shrink-0 text-zinc-600 transition-transform ${open ? "rotate-90" : ""}`}
      width="12"
      height="12"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
    >
      <path d="M9 18l6-6-6-6" />
    </svg>
  );
}

function TreeRow({
  node,
  depth,
  onFileSelect,
  selectedPath,
}: {
  node: TreeNode;
  depth: number;
  onFileSelect: (file: FileInfo) => void;
  selectedPath: string | null;
}) {
  const [open, setOpen] = useState(depth === 0);

  if (node.isDirectory) {
    return (
      <>
        <button
          onClick={() => setOpen(!open)}
          className="w-full flex items-center gap-1 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800/50 rounded transition-colors"
          style={{ paddingLeft: `${depth * 16 + 4}px` }}
        >
          <ChevronIcon open={open} />
          <FolderIcon open={open} />
          <span className="truncate">{node.name}</span>
        </button>
        {open && node.children.map((child) => (
          <TreeRow
            key={child.relativePath}
            node={child}
            depth={depth + 1}
            onFileSelect={onFileSelect}
            selectedPath={selectedPath}
          />
        ))}
      </>
    );
  }

  const isSelected = selectedPath === node.relativePath;

  return (
    <button
      onClick={() => {
        onFileSelect({
          name: node.name,
          type: getFileType(node.name),
          path: `/api/data/${node.relativePath}`,
          size: formatSize(node.size),
        });
      }}
      className={`w-full flex items-center gap-1.5 py-0.5 text-xs rounded transition-colors ${
        isSelected
          ? "bg-blue-600/20 text-blue-300"
          : "text-zinc-500 hover:bg-zinc-800/50 hover:text-zinc-300"
      }`}
      style={{ paddingLeft: `${depth * 16 + 20}px` }}
    >
      <FileIcon name={node.name} />
      <span className="truncate">{node.name}</span>
    </button>
  );
}

export default function FileTree({ onFileSelect, refreshTrigger }: FileTreeProps) {
  const [tree, setTree] = useState<TreeNode[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedPath, setSelectedPath] = useState<string | null>(null);

  const fetchFiles = useCallback(async () => {
    try {
      const res = await fetch("/api/files-list");
      const data = await res.json();
      if (data.files) {
        setTree(buildTree(data.files));
      }
    } catch {
      // Silently fail
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFiles();
  }, [fetchFiles, refreshTrigger]);

  const handleFileSelect = useCallback((file: FileInfo) => {
    // Extract relativePath from the API path
    const rel = file.path.replace("/api/data/", "");
    setSelectedPath(rel);
    onFileSelect(file);
  }, [onFileSelect]);

  if (loading) {
    return (
      <div className="px-2 py-3 text-xs text-zinc-600">Loading files...</div>
    );
  }

  if (tree.length === 0) {
    return (
      <div className="px-2 py-3 text-xs text-zinc-600">No files yet</div>
    );
  }

  return (
    <div className="py-1">
      {tree.map((node) => (
        <TreeRow
          key={node.relativePath}
          node={node}
          depth={0}
          onFileSelect={handleFileSelect}
          selectedPath={selectedPath}
        />
      ))}
    </div>
  );
}
