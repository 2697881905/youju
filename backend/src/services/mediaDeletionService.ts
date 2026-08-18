import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { deleteCosObjects, mediaKeyFromRef } from './uploadService';

const BATCH_SIZE = 50;
const MAX_RETRY_DELAY_MS = 24 * 60 * 60 * 1000;

export function mediaKeysFromValues(values: Array<string | null | undefined | unknown>): string[] {
  const keys: string[] = [];
  for (const value of values) {
    if (typeof value === 'string') {
      const key = mediaKeyFromRef(value);
      if (key) {
        keys.push(key);
      }
      continue;
    }
    if (Array.isArray(value)) {
      keys.push(...mediaKeysFromValues(value));
    }
  }
  return Array.from(new Set(keys));
}

export async function enqueueMediaDeletion(
  tx: Prisma.TransactionClient,
  values: Array<string | null | undefined | unknown>,
): Promise<void> {
  const keys = mediaKeysFromValues(values);
  if (keys.length === 0) {
    return;
  }
  await tx.mediaDeletionTask.createMany({
    data: keys.map((key) => ({ key })),
    skipDuplicates: true,
  });
}

function retryAt(attempts: number): Date {
  const delay = Math.min(MAX_RETRY_DELAY_MS, 60_000 * Math.pow(2, Math.min(attempts, 10)));
  return new Date(Date.now() + delay);
}

export async function runMediaDeletionBatch(): Promise<number> {
  const tasks = await prisma.mediaDeletionTask.findMany({
    where: { completedAt: null, nextAttemptAt: { lte: new Date() } },
    orderBy: { createdAt: 'asc' },
    take: BATCH_SIZE,
  });
  for (const task of tasks) {
    try {
      await deleteCosObjects([task.key]);
      await prisma.mediaDeletionTask.update({
        where: { id: task.id },
        data: { completedAt: new Date(), lastError: null },
      });
    } catch (error) {
      const attempts = task.attempts + 1;
      const message = error instanceof Error ? error.message : String(error);
      console.error('[media.delete] key=' + task.key, error);
      await prisma.mediaDeletionTask.update({
        where: { id: task.id },
        data: {
          attempts,
          nextAttemptAt: retryAt(attempts),
          lastError: message.slice(0, 1000),
        },
      });
    }
  }
  return tasks.length;
}

export function startMediaDeletionWorker(): void {
  void runMediaDeletionBatch().catch((error) => console.error('[media.delete] initial run', error));
  const timer = setInterval(() => {
    void runMediaDeletionBatch().catch((error) => console.error('[media.delete] scheduled run', error));
  }, 60_000);
  timer.unref();
}
