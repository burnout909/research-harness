"use client";

import { useCallback, useEffect, useRef, useState } from "react";

interface UseResizableOptions {
  direction: "horizontal" | "vertical";
  initialSize: number;
  minSize?: number;
  maxSize?: number;
}

export function useResizable({
  direction,
  initialSize,
  minSize = 60,
  maxSize = 2000,
}: UseResizableOptions) {
  const [size, setSize] = useState(initialSize);
  const isDragging = useRef(false);
  const startPos = useRef(0);
  const startSize = useRef(0);

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      isDragging.current = true;
      startPos.current = direction === "horizontal" ? e.clientX : e.clientY;
      startSize.current = size;
      document.body.style.cursor = direction === "horizontal" ? "col-resize" : "row-resize";
      document.body.style.userSelect = "none";
    },
    [direction, size],
  );

  useEffect(() => {
    const onMouseMove = (e: MouseEvent) => {
      if (!isDragging.current) return;
      const pos = direction === "horizontal" ? e.clientX : e.clientY;
      const delta = pos - startPos.current;
      const newSize = Math.min(maxSize, Math.max(minSize, startSize.current + delta));
      setSize(newSize);
    };

    const onMouseUp = () => {
      isDragging.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };

    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  }, [direction, minSize, maxSize]);

  return { size, onMouseDown };
}
