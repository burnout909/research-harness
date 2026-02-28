"use client";

import { useState, useCallback } from "react";
import Sidebar from "@/components/layout/Sidebar";
import ResizeHandle from "@/components/layout/ResizeHandle";
import { type SplitMode } from "@/components/layout/SplitToggle";
import ChatWindow from "@/components/chat/ChatWindow";
import ViewerPanel from "@/components/viewer/ViewerPanel";
import { useResizable } from "@/hooks/useResizable";
import { type UploadedFile } from "@/components/upload/FileUpload";
import { type FileInfo } from "@/components/viewer/FileCard";

const SIDEBAR_WIDTH = 220;

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

export default function Home() {
  const [splitMode, setSplitMode] = useState<SplitMode>("horizontal");
  const [uploadedFiles, setUploadedFiles] = useState<FileInfo[]>([]);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const viewerResize = useResizable({
    direction: splitMode === "horizontal" ? "horizontal" : "vertical",
    initialSize: splitMode === "horizontal" ? 600 : 400,
    minSize: 200,
    maxSize: 1200,
  });

  const toggleSplit = () => {
    setSplitMode((prev) => (prev === "horizontal" ? "vertical" : "horizontal"));
  };

  const handleFilesUploaded = useCallback((files: UploadedFile[]) => {
    const newFiles: FileInfo[] = files.map((f) => ({
      name: f.name,
      type: getFileType(f.name),
      path: f.path,
      size: formatSize(f.size),
      diskPath: f.diskPath,
    }));
    setUploadedFiles((prev) => [...prev, ...newFiles]);
  }, []);

  const handleFileSelect = useCallback((file: FileInfo) => {
    setUploadedFiles((prev) => {
      const exists = prev.some((f) => f.path === file.path);
      if (exists) return prev;
      return [...prev, file];
    });
  }, []);

  const handleFileCreated = useCallback((file: FileInfo) => {
    setUploadedFiles((prev) => {
      const exists = prev.some((f) => f.path === file.path);
      if (exists) return prev;
      return [...prev, file];
    });
    setRefreshTrigger((prev) => prev + 1);
  }, []);

  const handleRefresh = useCallback(() => {
    setRefreshTrigger((prev) => prev + 1);
  }, []);

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-zinc-950">
      {/* Left sidebar — fixed width, no resize */}
      <div style={{ width: SIDEBAR_WIDTH, minWidth: SIDEBAR_WIDTH }} className="flex-shrink-0">
        <Sidebar onFilesUploaded={handleFilesUploaded} onFileSelect={handleFileSelect} refreshTrigger={refreshTrigger} onRefresh={handleRefresh} />
      </div>

      {/* Main content area — viewer + chat */}
      <div className="flex-1 flex overflow-hidden">
        {splitMode === "horizontal" ? (
          // Horizontal split: viewer | chat (side by side)
          <>
            <div style={{ width: viewerResize.size }} className="flex-shrink-0 overflow-hidden">
              <ViewerPanel uploadedFiles={uploadedFiles} />
            </div>
            <ResizeHandle direction="horizontal" onMouseDown={viewerResize.onMouseDown} />
            <div className="flex-1 overflow-hidden">
              <ChatWindow splitMode={splitMode} onToggleSplit={toggleSplit} uploadedFiles={uploadedFiles} onFileCreated={handleFileCreated} />
            </div>
          </>
        ) : (
          // Vertical split: viewer on top, chat on bottom (stacked)
          <div className="flex flex-col flex-1 overflow-hidden">
            <div style={{ height: viewerResize.size }} className="flex-shrink-0 overflow-hidden">
              <ViewerPanel uploadedFiles={uploadedFiles} />
            </div>
            <ResizeHandle direction="vertical" onMouseDown={viewerResize.onMouseDown} />
            <div className="flex-1 overflow-hidden">
              <ChatWindow splitMode={splitMode} onToggleSplit={toggleSplit} uploadedFiles={uploadedFiles} onFileCreated={handleFileCreated} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
