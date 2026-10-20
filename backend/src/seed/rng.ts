// 确定性随机：同样的输入永远给同样的结果。
//
// 为什么不用 Math.random：造数脚本要能重跑、要在 dry-run 里预演「这次会写成什么样」，
// 还要能解释「为什么这条帖子的点赞是 137」。用帖子 id 做种子，增删别的帖子不会
// 打乱已发帖子的数值——按数组下标取种就做不到这一点。

export function fnv1a32(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

export interface Rng {
  next(): number;
  int(min: number, max: number): number;
  float(min: number, max: number): number;
  pick<T>(list: readonly T[]): T;
  chance(probability: number): boolean;
}

export function mulberry32(seed: number): Rng {
  let state = seed >>> 0;
  const next = (): number => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int(min: number, max: number): number {
      if (max <= min) return min;
      return min + Math.floor(next() * (max - min + 1));
    },
    float(min: number, max: number): number {
      return min + next() * (max - min);
    },
    pick<T>(list: readonly T[]): T {
      return list[Math.floor(next() * list.length)];
    },
    chance(probability: number): boolean {
      return next() < probability;
    },
  };
}

export function rngFor(key: string): Rng {
  return mulberry32(fnv1a32(key));
}
