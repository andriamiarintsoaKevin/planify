import { assertEquals } from "jsr:@std/assert@1";
import {
  createHandler,
  type HandlerDependencies,
  type ParseInput,
} from "./index.ts";

const validInput = {
  text: "appeler Marie demain 15 min, finir le devis 2h avant vendredi",
  timezone: "Europe/Paris",
  today: "2026-10-17",
};

const validTasks = {
  tasks: [
    {
      titre: "Appeler Marie",
      duree_minutes: 15,
      priorite: "medium",
      date_limite: "2026-10-18",
      notes: "",
    },
  ],
};

function createTestHandler(
  overrides: Partial<HandlerDependencies> = {},
) {
  const dependencies: HandlerDependencies = {
    dailyLimit: 3,
    authenticate: () => Promise.resolve({ id: "user-1" }),
    consumeQuota: () => Promise.resolve(true),
    generateTasks: () => Promise.resolve(validTasks),
    ...overrides,
  };
  const handler = createHandler(dependencies);
  const post = (body: unknown, token = "valid-token") =>
    handler(
      new Request("https://example.test/parse-tasks", {
        method: "POST",
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: JSON.stringify(body),
      }),
    );
  return { handler, post };
}

Deno.test("rejects calls without a bearer token", async () => {
  const { post } = createTestHandler();
  const response = await post(validInput, "");
  assertEquals(response.status, 401);
});

Deno.test("rejects an invalid JWT", async () => {
  const { post } = createTestHandler({
    authenticate: () => Promise.resolve(null),
  });
  const response = await post(validInput);
  assertEquals(response.status, 401);
});

Deno.test("reports authentication service errors as unavailable", async () => {
  const { post } = createTestHandler({
    authenticate: () => Promise.reject(new Error("auth service unavailable")),
  });
  const response = await post(validInput);
  assertEquals(response.status, 503);
  assertEquals((await response.json()).error, "auth_unavailable");
});

Deno.test("rejects invalid task JSON and retries once", async () => {
  let attempts = 0;
  const { post } = createTestHandler({
    generateTasks: (_input: ParseInput) => {
      attempts++;
      return Promise.resolve(
        attempts === 1
          ? { tasks: [{ titre: "", duree_minutes: "15" }] }
          : validTasks,
      );
    },
  });
  const response = await post(validInput);
  assertEquals(response.status, 200);
  assertEquals(attempts, 2);
});

Deno.test("returns a clear error after the single invalid-output retry", async () => {
  let attempts = 0;
  const { post } = createTestHandler({
    generateTasks: () => {
      attempts++;
      return Promise.resolve({ tasks: [{ titre: "", duree_minutes: 15 }] });
    },
  });
  const response = await post(validInput);
  assertEquals(response.status, 502);
  assertEquals(attempts, 2);
  assertEquals((await response.json()).error, "invalid_ai_response");
});

Deno.test("enforces the daily limit before calling Gemini", async () => {
  let generated = false;
  const { post } = createTestHandler({
    consumeQuota: (_userId, limit) => Promise.resolve(limit < 3),
    generateTasks: () => {
      generated = true;
      return Promise.resolve(validTasks);
    },
  });
  const response = await post(validInput);
  assertEquals(response.status, 429);
  assertEquals(generated, false);
});

Deno.test("rejects an oversized text without consuming quota", async () => {
  let consumed = false;
  const { post } = createTestHandler({
    consumeQuota: () => {
      consumed = true;
      return Promise.resolve(true);
    },
  });
  const response = await post({ ...validInput, text: "x".repeat(4001) });
  assertEquals(response.status, 400);
  assertEquals(consumed, false);
});
