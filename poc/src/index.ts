import express from "express";
import { usersRouter } from "./routes/users";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    runtime: "bun",
    bunVersion: Bun.version,
    timestamp: new Date().toISOString(),
  });
});

app.use("/users", usersRouter);

app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  console.log(`bun-poc-api listening on http://localhost:${port}`);
  console.log(`Runtime: Bun ${Bun.version}`);
});
