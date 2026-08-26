import { DurableObject } from "cloudflare:workers";

type LimitState = {
  count: number;
  resetsAt: number;
};

export type LimitResult = {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetsAt: number;
};

const DAILY_LIMIT = 20;
const DAY_IN_MS = 24 * 60 * 60 * 1_000;

export class SearchRateLimiter extends DurableObject<Env> {
  async consume(): Promise<LimitResult> {
    const now = Date.now();
    const stored = await this.ctx.storage.get<LimitState>("daily");
    const state = stored && stored.resetsAt > now
      ? stored
      : { count: 0, resetsAt: now + DAY_IN_MS };

    if (state.count >= DAILY_LIMIT) {
      return {
        allowed: false,
        limit: DAILY_LIMIT,
        remaining: 0,
        resetsAt: state.resetsAt
      };
    }

    const next = { ...state, count: state.count + 1 };
    await this.ctx.storage.put("daily", next);
    await this.ctx.storage.setAlarm(next.resetsAt);

    return {
      allowed: true,
      limit: DAILY_LIMIT,
      remaining: DAILY_LIMIT - next.count,
      resetsAt: next.resetsAt
    };
  }

  async alarm(): Promise<void> {
    await this.ctx.storage.deleteAll();
  }
}
