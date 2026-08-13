/**
 * COS 桶迁移：bigbluebook-1440002925 → youju-1440002925（同一地域服务端复制）
 * 运行：cd backend && npx tsx scripts/migrate-cos.ts
 * 前置：新桶 youju-1440002925 已在腾讯云控制台创建（同地域 ap-guangzhou）
 */
import dotenv from 'dotenv';
dotenv.config();
import COS from 'cos-nodejs-sdk-v5';

const OLD_BUCKET = 'bigbluebook-1440002925';
const NEW_BUCKET = 'youju-1440002925';
const REGION = process.env.COS_REGION ?? 'ap-guangzhou';

const secretId = process.env.COS_SECRET_ID ?? '';
const secretKey = process.env.COS_SECRET_KEY ?? '';
if (!secretId || !secretKey) {
  console.error('[migrate-cos] 错误：.env 缺少 COS_SECRET_ID / COS_SECRET_KEY');
  process.exit(1);
}
const cos = new COS({ SecretId: secretId, SecretKey: secretKey });

// 回调转 Promise
function promisify<T>(fn: (params: any, cb: (err: any, data: T) => void) => void) {
  return (params: any): Promise<T> =>
    new Promise((resolve, reject) => {
      fn.call(cos, params, (err: any, data: T) => (err ? reject(err) : resolve(data)));
    });
}
const headBucket = promisify<COS.HeadBucketResult>(cos.headBucket);
const getBucket = promisify<COS.GetBucketResult>(cos.getBucket);
const copyObject = promisify<COS.PutObjectCopyResult>(cos.putObjectCopy);

async function main(): Promise<void> {
  // 1. 校验新桶已存在
  try {
    await headBucket({ Bucket: NEW_BUCKET, Region: REGION });
    console.log(`[migrate-cos] 新桶 ${NEW_BUCKET} 存在 ✓`);
  } catch (e: any) {
    console.error(`[migrate-cos] 新桶 ${NEW_BUCKET} 不存在或无法访问：${e?.message ?? e}`);
    console.error('请先在腾讯云控制台创建同地域新桶，再重跑本脚本。');
    process.exit(1);
  }

  // 2. 列出旧桶全部对象（分页）
  console.log(`[migrate-cos] 正在列出旧桶 ${OLD_BUCKET} 对象...`);
  const keys: string[] = [];
  let marker = '';
  for (let round = 0; round < 1000; round++) {
    const data = await getBucket({ Bucket: OLD_BUCKET, Region: REGION, Marker: marker, MaxKeys: 1000 });
    for (const item of data.Contents ?? []) {
      if (item && item.Key && !item.Key.endsWith('/')) {
        keys.push(item.Key);
      }
    }
    if (!data.IsTruncated) break;
    marker = data.NextMarker ?? '';
  }
  console.log(`[migrate-cos] 旧桶共 ${keys.length} 个对象`);

  // 3. 并发服务端复制到新桶（并发池 20，避免串行过慢）
  const CONCURRENCY = 20;
  const failed: string[] = [];
  let done = 0;
  let nextIdx = 0;
  const worker = async (): Promise<void> => {
    while (nextIdx < keys.length) {
      const i = nextIdx++;
      const key = keys[i];
      // 分段编码：保留路径分隔符 /（CopySource 的 key 部分按段编码，避免 %2F 解析问题）
      const encKey = key.split('/').map((seg) => encodeURIComponent(seg)).join('/');
      const copySource = `${OLD_BUCKET}.cos.${REGION}.myqcloud.com/${encKey}`;
      try {
        await copyObject({ Bucket: NEW_BUCKET, Region: REGION, Key: key, CopySource: copySource });
      } catch (e: any) {
        failed.push(`${key}（${e?.message ?? e}）`);
      }
      done++;
      if (done % 200 === 0 || done === keys.length) {
        console.log(`[migrate-cos] 已复制 ${done}/${keys.length}`);
      }
    }
  };
  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()));

  // 4. 汇总
  if (failed.length === 0) {
    console.log(`[migrate-cos] ✅ 全部 ${keys.length} 个对象复制成功`);
  } else {
    console.log(`[migrate-cos] ⚠️ ${failed.length} 个对象失败：`);
    for (const f of failed.slice(0, 20)) {
      console.log('  - ' + f);
    }
    process.exitCode = 1;
  }
}

main().catch((e) => {
  console.error('[migrate-cos] 异常：', e);
  process.exit(1);
});
