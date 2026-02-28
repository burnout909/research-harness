import { NextResponse } from "next/server";
import { readdir, stat } from "fs/promises";
import path from "path";

const DATA_DIR = path.join(process.cwd(), "..", "data");

interface FileEntry {
  name: string;
  relativePath: string;
  size: number;
  isDirectory: boolean;
}

async function scanDir(dir: string, baseDir: string): Promise<FileEntry[]> {
  const entries: FileEntry[] = [];

  let items: string[];
  try {
    items = await readdir(dir);
  } catch {
    return entries;
  }

  for (const item of items) {
    if (item.startsWith(".")) continue;
    if (HIDDEN_FILES.has(item)) continue;
    if (HIDDEN_EXTENSIONS.has(path.extname(item).toLowerCase())) continue;

    const fullPath = path.join(dir, item);
    try {
      const s = await stat(fullPath);
      const relativePath = path.relative(baseDir, fullPath);

      entries.push({
        name: item,
        relativePath,
        size: s.isDirectory() ? 0 : s.size,
        isDirectory: s.isDirectory(),
      });

      if (s.isDirectory()) {
        const children = await scanDir(fullPath, baseDir);
        entries.push(...children);
      }
    } catch {
      // Skip inaccessible files
    }
  }

  return entries;
}

const VISIBLE_DIRS = ["originals", "working", "outputs"];

// Hide temporary/internal files from the file tree
const HIDDEN_FILES = new Set(["_run.m", "mcp_run.m", "experiment_result.json"]);
const HIDDEN_EXTENSIONS = new Set([".mat"]);

export async function GET() {
  try {
    const files: FileEntry[] = [];

    for (const dir of VISIBLE_DIRS) {
      const dirPath = path.join(DATA_DIR, dir);
      // Add the top-level directory entry itself
      try {
        const s = await stat(dirPath);
        if (s.isDirectory()) {
          files.push({
            name: dir,
            relativePath: dir,
            size: 0,
            isDirectory: true,
          });
          const children = await scanDir(dirPath, DATA_DIR);
          files.push(...children);
        }
      } catch {
        // Directory doesn't exist yet, skip
      }
    }

    // Sort: directories first, then alphabetically
    files.sort((a, b) => {
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.relativePath.localeCompare(b.relativePath);
    });

    return NextResponse.json({ files });
  } catch (error) {
    console.error("File listing error:", error);
    return NextResponse.json({ error: "Failed to list files" }, { status: 500 });
  }
}
