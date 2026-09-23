import { DurableObject } from "cloudflare:workers";

type DownloadCounts = Record<string, number>;

export class ModelDownloadCounter extends DurableObject<Env> {
  async record(modelID: string, installationID: string): Promise<void> {
    const seenKey = `seen:${modelID}:${installationID}`;
    if (await this.ctx.storage.get<boolean>(seenKey)) return;

    const counts = await this.ctx.storage.get<DownloadCounts>("counts") ?? {};
    counts[modelID] = (counts[modelID] ?? 0) + 1;
    await this.ctx.storage.put("counts", counts);
    await this.ctx.storage.put(seenKey, true);
  }

  async counts(): Promise<DownloadCounts> {
    return await this.ctx.storage.get<DownloadCounts>("counts") ?? {};
  }
}
