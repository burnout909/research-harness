"use client";

import { useEffect, useState } from "react";
import * as XLSX from "xlsx";

interface ExcelViewerProps {
  filePath?: string;
  fileData?: ArrayBuffer;
}

export default function ExcelViewer({ filePath, fileData }: ExcelViewerProps) {
  const [sheets, setSheets] = useState<string[]>([]);
  const [activeSheet, setActiveSheet] = useState("");
  const [rows, setRows] = useState<string[][]>([]);

  useEffect(() => {
    if (!fileData) return;

    try {
      const wb = XLSX.read(fileData, { type: "array" });
      setSheets(wb.SheetNames);
      if (wb.SheetNames.length > 0) {
        setActiveSheet(wb.SheetNames[0]);
        const data = XLSX.utils.sheet_to_json<string[]>(wb.Sheets[wb.SheetNames[0]], { header: 1 });
        setRows(data);
      }
    } catch {
      setSheets([]);
      setActiveSheet("");
      setRows([]);
    }
  }, [fileData]);

  const switchSheet = (name: string) => {
    if (!fileData) return;
    setActiveSheet(name);
    try {
      const wb = XLSX.read(fileData, { type: "array" });
      const data = XLSX.utils.sheet_to_json<string[]>(wb.Sheets[name], { header: 1 });
      setRows(data);
    } catch {
      setRows([]);
    }
  };

  if (!fileData) {
    return (
      <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
        Select an Excel file to preview
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Sheet tabs */}
      {sheets.length > 1 && (
        <div className="flex gap-1 px-3 py-1.5 border-b border-zinc-800 overflow-x-auto">
          {sheets.map((s) => (
            <button
              key={s}
              onClick={() => switchSheet(s)}
              className={`px-2 py-1 text-xs rounded transition-colors ${
                s === activeSheet ? "bg-blue-600 text-white" : "bg-zinc-800 text-zinc-400 hover:text-zinc-200"
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      )}

      {/* Table */}
      <div className="flex-1 overflow-auto">
        <table className="w-full text-xs border-collapse">
          <tbody>
            {rows.map((row, ri) => (
              <tr key={ri} className={ri === 0 ? "bg-zinc-800 sticky top-0" : "hover:bg-zinc-800/50"}>
                {(row as unknown[]).map((cell, ci) => {
                  const Tag = ri === 0 ? "th" : "td";
                  return (
                    <Tag
                      key={ci}
                      className="border border-zinc-700 px-2 py-1 text-left text-zinc-300 whitespace-nowrap"
                    >
                      {cell != null ? String(cell) : ""}
                    </Tag>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
