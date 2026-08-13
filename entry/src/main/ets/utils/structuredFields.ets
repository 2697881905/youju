import { Genre, StructuredData } from '../models/types';

export type StructuredFieldDef = [keyof StructuredData, string];

export function genreStructuredFields(genre: Genre): StructuredFieldDef[] {
  switch (genre) {
    case 'review':
      return [['pros', '优点'], ['cons', '缺点'], ['rating', '推荐指数'], ['targetAudience', '适合人群']];
    case 'pitfall':
      return [['pitfallExperience', '踩坑经历'], ['lossAmount', '损失金额'], ['correctApproach', '正确做法']];
    case 'tutorial':
      return [['tools', '准备工具'], ['steps', '步骤拆解'], ['timeDifficulty', '耗时/难度']];
    case 'debate':
      return [['planA', '方案A'], ['planB', '方案B']];
    case 'share':
      return [];
    default:
      return [];
  }
}

// ArkTS V1 不允许以变量索引对象，使用显式 switch 保持字段访问与序列化稳定。
export function readStructuredField(data: StructuredData, key: keyof StructuredData): string | number | undefined {
  switch (key) {
    case 'pros': return data.pros;
    case 'cons': return data.cons;
    case 'rating': return data.rating;
    case 'targetAudience': return data.targetAudience;
    case 'pitfallExperience': return data.pitfallExperience;
    case 'lossAmount': return data.lossAmount;
    case 'correctApproach': return data.correctApproach;
    case 'tools': return data.tools;
    case 'steps': return data.steps;
    case 'timeDifficulty': return data.timeDifficulty;
    case 'planA': return data.planA;
    case 'planB': return data.planB;
    default: return undefined;
  }
}

export function withStructuredField(data: StructuredData, key: keyof StructuredData, value: string): StructuredData {
  const next: StructuredData = {
    coverOnlyTextPoster: data.coverOnlyTextPoster,
    pros: data.pros,
    cons: data.cons,
    rating: data.rating,
    targetAudience: data.targetAudience,
    pitfallExperience: data.pitfallExperience,
    lossAmount: data.lossAmount,
    correctApproach: data.correctApproach,
    tools: data.tools,
    steps: data.steps,
    timeDifficulty: data.timeDifficulty,
    planA: data.planA,
    planB: data.planB,
  };
  switch (key) {
    case 'pros': next.pros = value; break;
    case 'cons': next.cons = value; break;
    case 'rating': next.rating = value; break;
    case 'targetAudience': next.targetAudience = value; break;
    case 'pitfallExperience': next.pitfallExperience = value; break;
    case 'lossAmount': next.lossAmount = value; break;
    case 'correctApproach': next.correctApproach = value; break;
    case 'tools': next.tools = value; break;
    case 'steps': next.steps = value; break;
    case 'timeDifficulty': next.timeDifficulty = value; break;
    case 'planA': next.planA = value; break;
    case 'planB': next.planB = value; break;
    default: break;
  }
  return next;
}

export function withCoverOnlyTextPoster(data: StructuredData, enabled: boolean): StructuredData {
  return {
    coverOnlyTextPoster: enabled,
    pros: data.pros,
    cons: data.cons,
    rating: data.rating,
    targetAudience: data.targetAudience,
    pitfallExperience: data.pitfallExperience,
    lossAmount: data.lossAmount,
    correctApproach: data.correctApproach,
    tools: data.tools,
    steps: data.steps,
    timeDifficulty: data.timeDifficulty,
    planA: data.planA,
    planB: data.planB,
  };
}

export function isLongStructuredField(key: keyof StructuredData): boolean {
  return key === 'pros' || key === 'cons' || key === 'pitfallExperience' ||
    key === 'correctApproach' || key === 'steps' || key === 'tools' ||
    key === 'planA' || key === 'planB';
}
