import { Database } from "bun:sqlite";

export const db = new Database("data.sqlite", { create: true });

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  );
`);

export type User = {
  id: number;
  name: string;
  email: string;
  created_at: string;
};
