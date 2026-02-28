"use client";

import { useState } from "react";
import FileUpload, { type UploadedFile } from "@/components/upload/FileUpload";
import FileTree from "@/components/layout/FileTree";
import { type FileInfo } from "@/components/viewer/FileCard";

interface SidebarProps {
  onNewSession?: () => void;
  onFilesUploaded?: (files: UploadedFile[]) => void;
  onFileSelect?: (file: FileInfo) => void;
  refreshTrigger?: number;
  onRefresh?: () => void;
}

interface NavItem {
  id: string;
  label: string;
  icon: React.ReactNode;
}

const NAV_ITEMS: NavItem[] = [
  {
    id: "files",
    label: "Files",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
      </svg>
    ),
  },
  {
    id: "sessions",
    label: "Sessions",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
      </svg>
    ),
  },
  {
    id: "tools",
    label: "Tools",
    icon: (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
        <path d="M14.7 6.3a1 1 0 000 1.4l1.6 1.6a1 1 0 001.4 0l3.77-3.77a6 6 0 01-7.94 7.94l-6.91 6.91a2.12 2.12 0 01-3-3l6.91-6.91a6 6 0 017.94-7.94l-3.76 3.76z" />
      </svg>
    ),
  },
];

export default function Sidebar({ onNewSession, onFilesUploaded, onFileSelect, refreshTrigger = 0, onRefresh }: SidebarProps) {
  const [activeNav, setActiveNav] = useState("files");

  const handleUploadComplete = (files: UploadedFile[]) => {
    onFilesUploaded?.(files);
    onRefresh?.();
  };

  return (
    <div className="flex flex-col h-full bg-zinc-950 border-r border-zinc-800">
      {/* Logo area */}
      <div className="px-3 py-3 border-b border-zinc-800 flex-shrink-0">
        <h1 className="text-sm font-bold text-zinc-200 tracking-tight">Research Harness</h1>
      </div>

      {/* Navigation */}
      <nav className="flex flex-col gap-0.5 px-2 py-2 flex-shrink-0">
        {NAV_ITEMS.map((item) => (
          <button
            key={item.id}
            onClick={() => setActiveNav(item.id)}
            className={`
              flex items-center gap-2.5 px-2.5 py-1.5 rounded-md text-sm transition-colors
              ${activeNav === item.id
                ? "bg-zinc-800 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800/50"
              }
            `}
          >
            {item.icon}
            {item.label}
          </button>
        ))}
      </nav>

      {/* Content area based on active nav */}
      <div className="flex-1 overflow-y-auto px-2 py-2">
        {activeNav === "files" && (
          <div className="flex flex-col h-full">
            <div className="flex-shrink-0">
              <FileUpload compact onUploadComplete={handleUploadComplete} />
            </div>
            <div className="flex-1 overflow-y-auto mt-1">
              <FileTree onFileSelect={(file) => onFileSelect?.(file)} refreshTrigger={refreshTrigger} />
            </div>
          </div>
        )}
        {activeNav === "sessions" && (
          <div className="space-y-1">
            <button
              onClick={onNewSession}
              className="w-full text-left px-2 py-1.5 text-xs text-blue-400 hover:text-blue-300 hover:bg-zinc-800/50 rounded transition-colors"
            >
              + New Session
            </button>
            <div className="text-xs text-zinc-600 px-2 py-1 uppercase tracking-wider">Recent</div>
            <div className="px-2 py-1 text-xs text-zinc-600">No sessions yet</div>
          </div>
        )}
        {activeNav === "tools" && (
          <div className="space-y-1">
            <div className="text-xs text-zinc-600 px-2 py-1 uppercase tracking-wider">MCP Tools</div>
            {[
              "read_excel", "write_excel", "read_docx", "write_docx",
              "analyze_data", "create_plot", "run_matlab", "generate_manuscript",
            ].map((tool) => (
              <div key={tool} className="px-2 py-1 text-xs text-zinc-500 font-mono">
                {tool}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Bottom */}
      <div className="px-3 py-2 border-t border-zinc-800 flex-shrink-0">
        <div className="text-xs text-zinc-600">v0.1.0</div>
      </div>
    </div>
  );
}
