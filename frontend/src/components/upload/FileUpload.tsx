"use client";

import { useState, useRef, useCallback } from "react";

export interface UploadedFile {
  name: string;
  path: string;
  size: number;
}

interface FileUploadProps {
  onUploadComplete: (files: UploadedFile[]) => void;
}

export default function FileUpload({ onUploadComplete }: FileUploadProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [progress, setProgress] = useState<string>("");
  const inputRef = useRef<HTMLInputElement>(null);

  const upload = useCallback(async (fileList: FileList | File[]) => {
    const files = Array.from(fileList);
    if (files.length === 0) return;

    setIsUploading(true);
    setProgress(`Uploading ${files.length} file${files.length > 1 ? "s" : ""}...`);

    const formData = new FormData();
    for (const file of files) {
      formData.append("files", file);
    }

    try {
      const res = await fetch("/api/upload", { method: "POST", body: formData });
      const data = await res.json();

      if (!res.ok) {
        setProgress(`Error: ${data.error}`);
        return;
      }

      const uploaded: UploadedFile[] = data.uploaded || [];
      const errors: { name: string; error: string }[] = data.errors || [];

      if (errors.length > 0) {
        setProgress(`${uploaded.length} uploaded, ${errors.length} failed`);
      } else {
        setProgress(`${uploaded.length} file${uploaded.length > 1 ? "s" : ""} uploaded`);
      }

      if (uploaded.length > 0) {
        onUploadComplete(uploaded);
      }
    } catch {
      setProgress("Upload failed — check connection");
    } finally {
      setIsUploading(false);
      setTimeout(() => setProgress(""), 3000);
    }
  }, [onUploadComplete]);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    const items = e.dataTransfer.items;
    const files: File[] = [];

    // Collect files (including from folders)
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.kind === "file") {
        const file = item.getAsFile();
        if (file) files.push(file);
      }
    }

    if (files.length > 0) upload(files);
  }, [upload]);

  const handleInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      upload(e.target.files);
      e.target.value = "";
    }
  }, [upload]);

  return (
    <div className="px-3 py-2">
      <div
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => !isUploading && inputRef.current?.click()}
        className={`
          relative flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed
          px-4 py-6 cursor-pointer transition-all text-center
          ${isDragging
            ? "border-blue-500 bg-blue-500/10 text-blue-400"
            : "border-zinc-700 hover:border-zinc-500 text-zinc-500 hover:text-zinc-400"
          }
          ${isUploading ? "pointer-events-none opacity-60" : ""}
        `}
      >
        {isUploading ? (
          <svg className="animate-spin" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
          </svg>
        ) : (
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M17 8l-5-5-5 5M12 3v12" />
          </svg>
        )}
        <div className="text-xs">
          {isUploading ? progress : (
            <>
              <span className="font-medium">Click to upload</span> or drag & drop
              <br />
              <span className="text-zinc-600">xlsx, docx, csv, pdf, png, jpg, mat</span>
            </>
          )}
        </div>

        <input
          ref={inputRef}
          type="file"
          multiple
          className="hidden"
          accept=".xlsx,.xls,.csv,.docx,.doc,.pdf,.png,.jpg,.jpeg,.svg,.mat,.m,.txt,.json"
          onChange={handleInputChange}
        />
      </div>

      {progress && !isUploading && (
        <div className="mt-2 text-xs text-center text-green-400">{progress}</div>
      )}
    </div>
  );
}
