import { Router } from "express";
import { z } from "zod";
import { db, type User } from "../db";

export const usersRouter = Router();

const createUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

usersRouter.get("/", (_req, res) => {
  const rows = db.query("SELECT * FROM users ORDER BY id DESC").all() as User[];
  res.json(rows);
});

usersRouter.get("/:id", (req, res) => {
  const user = db
    .query("SELECT * FROM users WHERE id = ?")
    .get(req.params.id) as User | null;
  if (!user) return res.status(404).json({ error: "User not found" });
  res.json(user);
});

usersRouter.post("/", (req, res) => {
  const parsed = createUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }
  try {
    const { lastInsertRowid } = db
      .query("INSERT INTO users (name, email) VALUES (?, ?)")
      .run(parsed.data.name, parsed.data.email);
    const user = db
      .query("SELECT * FROM users WHERE id = ?")
      .get(lastInsertRowid) as User;
    res.status(201).json(user);
  } catch (err: any) {
    if (String(err.message).includes("UNIQUE")) {
      return res.status(409).json({ error: "Email already exists" });
    }
    throw err;
  }
});

usersRouter.delete("/:id", (req, res) => {
  const result = db
    .query("DELETE FROM users WHERE id = ?")
    .run(req.params.id);
  if (result.changes === 0) return res.status(404).json({ error: "Not found" });
  res.status(204).end();
});
