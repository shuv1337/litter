import { Env, RegisterRequest } from "./types"

export { PushRegistration } from "./durable-object"
export { RateLimiter } from "./rate-limiter"

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json" },
  })
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    const parts = url.pathname.split("/").filter(Boolean)

    if (request.method === "POST" && parts.length === 1 && parts[0] === "register") {
      const ip = request.headers.get("cf-connecting-ip") ?? "unknown"
      const limitId = env.RATE_LIMITER.idFromName(ip)
      const limiter = env.RATE_LIMITER.get(limitId)
      const limitResp = await limiter.fetch(new Request("https://rl/check"))
      if (limitResp.status === 429) {
        return json({ error: "rate limited" }, 429)
      }

      const body = (await request.json()) as RegisterRequest
      const id = env.PUSH_REGISTRATION.newUniqueId()
      const stub = env.PUSH_REGISTRATION.get(id)
      await stub.fetch(new Request("https://do/", { method: "PUT", body: JSON.stringify(body) }))
      return json({ id: id.toString() })
    }

    if (parts.length === 2 && request.method === "POST") {
      const [doId, action] = parts
      if (!["deregister"].includes(action)) return json({ error: "not found" }, 404)
      const id = env.PUSH_REGISTRATION.idFromString(doId)
      const stub = env.PUSH_REGISTRATION.get(id)
      const doReq = new Request(`https://do/${action}`, {
        method: "POST",
        body: request.body,
        headers: request.headers,
      })
      const resp = await stub.fetch(doReq)
      return new Response(resp.body, { status: resp.status })
    }

    return json({ error: "not found" }, 404)
  },
}
