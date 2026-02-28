"use client";

import { useState, useEffect, useCallback } from "react";
import FileCard, { type FileInfo } from "./FileCard";
import ExcelViewer from "./ExcelViewer";
import DocxViewer from "./DocxViewer";
import ImageViewer from "./ImageViewer";

interface ViewerPanelProps {
  uploadedFiles?: FileInfo[];
}

export default function ViewerPanel({ uploadedFiles = [] }: ViewerPanelProps) {
  const [files, setFiles] = useState<FileInfo[]>([]);
  const [activeFile, setActiveFile] = useState<FileInfo | null>(null);
  const [fileData, setFileData] = useState<ArrayBuffer | null>(null);
  const [loading, setLoading] = useState(false);

  // Add uploaded files to the list
  useEffect(() => {
    if (uploadedFiles.length === 0) return;
    setFiles((prev) => {
      const existingPaths = new Set(prev.map((f) => f.path));
      const newFiles = uploadedFiles.filter((f) => !existingPaths.has(f.path));
      if (newFiles.length === 0) return prev;
      return [...prev, ...newFiles];
    });
  }, [uploadedFiles]);

  // Auto-select the latest uploaded file
  useEffect(() => {
    if (uploadedFiles.length > 0) {
      const latest = uploadedFiles[uploadedFiles.length - 1];
      setActiveFile(latest);
    }
  }, [uploadedFiles]);

  // Fetch file data when active file changes
  const fetchFileData = useCallback(async (file: FileInfo) => {
    setLoading(true);
    setFileData(null);
    try {
      const res = await fetch(file.path);
      if (!res.ok) throw new Error("Failed to fetch");
      const buf = await res.arrayBuffer();
      setFileData(buf);
    } catch {
      setFileData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (activeFile) {
      fetchFileData(activeFile);
    } else {
      setFileData(null);
    }
  }, [activeFile, fetchFileData]);

  const handleRemoveFile = (file: FileInfo) => {
    setFiles((prev) => prev.filter((f) => f.path !== file.path));
    if (activeFile?.path === file.path) {
      setActiveFile(null);
    }
  };

  const renderViewer = () => {
    if (!activeFile) {
      return (
        <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
          <div className="text-center">
            <svg className="mx-auto mb-3 text-zinc-600" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M17 8l-5-5-5 5M12 3v12" />
            </svg>
            <p className="text-lg mb-1">No file selected</p>
            <p>Upload files from the sidebar to preview</p>
          </div>
        </div>
      );
    }

    if (loading) {
      return (
        <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
          <svg className="animate-spin mr-2" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
          </svg>
          Loading...
        </div>
      );
    }

    switch (activeFile.type) {
      case "xlsx":
      case "csv":
        return <ExcelViewer fileData={fileData ?? undefined} />;
      case "docx":
        return <DocxViewer fileData={fileData ?? undefined} />;
      case "png":
      case "jpg":
      case "svg":
        return <ImageViewer src={activeFile.path} alt={activeFile.name} />;
      case "pdf":
        return (
          <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
            PDF viewer — coming soon
          </div>
        );
      default:
        return (
          <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
            Unsupported file type
          </div>
        );
    }
  };

  return (
    <div className="flex flex-col h-full bg-zinc-900">
      {/* Title bar with download button */}
      <div className="flex items-center justify-between px-4 py-2 border-b border-zinc-800 flex-shrink-0">
        <h2 className="text-sm font-medium text-zinc-300">
          {activeFile ? activeFile.name : "Viewer"}
        </h2>
        {activeFile && (
          <a
            href={activeFile.path}
            download={activeFile.name}
            className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors px-2 py-1 rounded hover:bg-zinc-800"
          >
            Download
          </a>
        )}
      </div>

      {/* File tabs */}
      {files.length > 0 && (
        <div className="flex gap-1 px-3 py-1.5 border-b border-zinc-800 overflow-x-auto flex-shrink-0">
          {files.map((f) => (
            <div key={f.path} className="relative group">
              <FileCard
                file={f}
                isActive={activeFile?.path === f.path}
                onClick={() => setActiveFile(f)}
              />
              <button
                onClick={(e) => { e.stopPropagation(); handleRemoveFile(f); }}
                className="absolute -top-1 -right-1 w-4 h-4 bg-zinc-700 rounded-full text-zinc-400 hover:bg-red-600 hover:text-white text-[10px] leading-none hidden group-hover:flex items-center justify-center"
              >
                x
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Viewer area */}
      <div className="flex-1 overflow-hidden">
        {renderViewer()}
      </div>
    </div>
  );
}
