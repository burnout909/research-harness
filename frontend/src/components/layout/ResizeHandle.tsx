"use client";

interface ResizeHandleProps {
  direction: "horizontal" | "vertical";
  onMouseDown: (e: React.MouseEvent) => void;
}

export default function ResizeHandle({ direction, onMouseDown }: ResizeHandleProps) {
  const isH = direction === "horizontal";

  return (
    <div
      onMouseDown={onMouseDown}
      className={`
        group relative flex-shrink-0 z-10
        ${isH ? "w-1 cursor-col-resize" : "h-1 cursor-row-resize"}
        bg-zinc-800 hover:bg-blue-500 transition-colors duration-150
      `}
    >
      {/* Wider invisible hit area */}
      <div
        className={`
          absolute
          ${isH ? "top-0 bottom-0 -left-1.5 -right-1.5" : "left-0 right-0 -top-1.5 -bottom-1.5"}
        `}
      />
    </div>
  );
}
