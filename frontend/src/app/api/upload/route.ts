import { NextRequest, NextResponse } from "next/server";
import { writeFile, mkdir } from "fs/promises";
import path from "path";

const UPLOAD_DIR = path.join(process.cwd(), "..", "data", "uploads");

const ALLOWED_EXTENSIONS = new Set([
  ".xlsx", ".xls", ".csv",
  ".docx", ".doc",
  ".pdf",
  ".png", ".jpg", ".jpeg", ".svg",
  ".mat", ".m",
  ".txt", ".json",
]);

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const files = formData.getAll("files") as File[];

    if (files.length === 0) {
      return NextResponse.json({ error: "No files provided" }, { status: 400 });
    }

    await mkdir(UPLOAD_DIR, { recursive: true });

    const results: { name: string; path: string; size: number }[] = [];
    const errors: { name: string; error: string }[] = [];

    for (const file of files) {
      const ext = path.extname(file.name).toLowerCase();

      if (!ALLOWED_EXTENSIONS.has(ext)) {
        errors.push({ name: file.name, error: `Unsupported file type: ${ext}` });
        continue;
      }

      if (file.size > MAX_FILE_SIZE) {
        errors.push({ name: file.name, error: `File too large (max ${MAX_FILE_SIZE / 1024 / 1024}MB)` });
        continue;
      }

      // Sanitize filename: keep only alphanumeric, dash, underscore, dot, Korean chars
      const safeName = file.name.replace(/[^a-zA-Z0-9가-힣._-]/g, "_");
      const timestamp = Date.now();
      const uniqueName = `${timestamp}_${safeName}`;
      const filePath = path.join(UPLOAD_DIR, uniqueName);

      const buffer = Buffer.from(await file.arrayBuffer());
      await writeFile(filePath, buffer);

      results.push({
        name: file.name,
        path: `/api/files/${uniqueName}`,
        size: file.size,
      });
    }

    return NextResponse.json({ uploaded: results, errors });
  } catch (error) {
    console.error("Upload error:", error);
    return NextResponse.json({ error: "Upload failed" }, { status: 500 });
  }
}
