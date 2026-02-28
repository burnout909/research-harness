"use client";

import { useEffect, useState } from "react";
import mammoth from "mammoth";

interface DocxViewerProps {
  fileData?: ArrayBuffer;
}

export default function DocxViewer({ fileData }: DocxViewerProps) {
  const [html, setHtml] = useState("");

  useEffect(() => {
    if (!fileData) return;
    mammoth
      .convertToHtml({ arrayBuffer: fileData })
      .then((result) => setHtml(result.value))
      .catch(() => setHtml("<p>Failed to render document.</p>"));
  }, [fileData]);

  if (!fileData) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
        Select a DOCX file to preview
      </div>
    );
  }

  return (
    <div className="h-full overflow-auto p-4">
      <div
        className="prose prose-invert prose-sm max-w-none"
        dangerouslySetInnerHTML={{ __html: html }}
      />
    </div>
  );
}
