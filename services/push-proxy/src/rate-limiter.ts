const MAX_REQUESTS = 10
const WINDOW_MS = 60_000

export class RateLimiter implements DurableObject {
  private state: DurableObjectState
  private timestamps: number[] = []

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(_request: Request): Promise<Response> {
    const now = Date.now()
    this.timestamps = this.timestamps.filter((t) => now - t < WINDOW_MS)
    if (this.timestamps.length >= MAX_REQUESTS) {
      return new Response("rate limited", { status: 429 })
    }
    this.timestamps.push(now)
    return new Response("ok")
  }
}
