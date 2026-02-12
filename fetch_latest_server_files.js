// fetch_latest_server_files.js
// Purpose: Find the latest "ServerFiles-*.zip" for the CurseForge modpack,
// then update launch.sh values: SERVER_VERSION + SERVER_FILE_ID.
//
// Required env:
// - CURSEFORGE_API_KEY (GitHub secret)

import fs from "node:fs";

const PROJECT_ID = 1356598; // All the Mons - ATMons
const API_URL = `https://api.curseforge.com/v1/mods/${PROJECT_ID}/files?pageSize=50&sortField=FileDate&sortOrder=desc`;

function mustGetEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

function parseServerVersionFromFileName(fileName) {
  // expected: ServerFiles-0.10.0-beta.zip
  const m = /^ServerFiles-(.+)\.zip$/.exec(fileName);
  return m ? m[1] : null;
}

function replaceOrThrow(haystack, pattern, replacement) {
  if (!pattern.test(haystack)) {
    throw new Error(`Pattern not found in launch.sh: ${pattern}`);
  }
  return haystack.replace(pattern, replacement);
}

async function main() {
  const apiKey = mustGetEnv("CURSEFORGE_API_KEY");

  const res = await fetch(API_URL, {
    headers: {
      "x-api-key": apiKey,
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`CurseForge API error ${res.status}: ${body}`);
  }

  const json = await res.json();
  const files = json?.data ?? [];

  // Prefer isServerPack when available; fallback to filename convention.
  const serverFiles = files
    .filter(
      (f) =>
        f?.isServerPack === true ||
        (typeof f?.fileName === "string" &&
          f.fileName.startsWith("ServerFiles-") &&
          f.fileName.endsWith(".zip"))
    )
    .map((f) => ({
      id: f.id,
      fileName: f.fileName,
      fileDate: f.fileDate,
      serverVersion: parseServerVersionFromFileName(f.fileName || ""),
    }))
    .filter((f) => f.serverVersion);

  if (serverFiles.length === 0) {
    throw new Error("No ServerFiles-*.zip (or isServerPack=true) found for this project.");
  }

  // Newest by fileDate; tie-breaker: highest id
  serverFiles.sort((a, b) => {
    const ad = Date.parse(a.fileDate || "") || 0;
    const bd = Date.parse(b.fileDate || "") || 0;
    if (bd !== ad) return bd - ad;
    return (b.id || 0) - (a.id || 0);
  });

  const latest = serverFiles[0];
  console.log("Latest ServerFiles:", latest);

  const launchPath = "launch.sh";
  const launch = fs.readFileSync(launchPath, "utf8");

  // Update exactly the lines we expect in launch.sh
  const updated = [
    [/^SERVER_VERSION=".*"$/m, `SERVER_VERSION="${latest.serverVersion}"`],
    [/^SERVER_FILE_ID=\d+$/m, `SERVER_FILE_ID=${latest.id}`],
  ].reduce((acc, [pat, rep]) => replaceOrThrow(acc, pat, rep), launch);

  if (updated === launch) {
    console.log("No changes needed.");
    return;
  }

  fs.writeFileSync(launchPath, updated, "utf8");
  console.log(`Updated ${launchPath} -> SERVER_VERSION=${latest.serverVersion}, SERVER_FILE_ID=${latest.id}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});