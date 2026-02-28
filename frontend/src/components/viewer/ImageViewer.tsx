"use client";

interface ImageViewerProps {
  src?: string;
  alt?: string;
}

export default function ImageViewer({ src, alt = "Image" }: ImageViewerProps) {
  if (!src) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
        Select an image to preview
      </div>
    );
  }

  return (
    <div className="h-full overflow-auto flex items-center justify-center p-4 bg-zinc-950">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} className="max-w-full max-h-full object-contain" />
    </div>
  );
}
