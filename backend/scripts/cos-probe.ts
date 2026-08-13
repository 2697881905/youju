/**
 * COS 连通性诊断：验证密钥对旧桶/新桶的读写访问，定位迁移脚本卡住原因
 * 运行：cd backend && npx tsx scripts/cos-probe.ts
 */
import dotenv from 'dotenv';
dotenv.config();
import COS from 'cos-nodejs-sdk-v5';

const OLD_BUCKET = 'bigbluebook-1440002925';
const NEW_BUCKET = 'youju-1440002925';
const REGION = process.env.COS_REGION ?? 'ap-guangzhou';
const secretId = process.env.COS_SECRET_ID ?? '';
const secretKey = process.env.COS_SECRET_KEY ?? '';

console.log(`[probe] region=${REGION}`);
console.log(`[probe] secretId=${secretId ? secretId.slice(0, 6) + '...' : '缺失'}`);
console.log(`[probe] secretKey=${secretKey ? '已配置(' + secretKey.length + '位)' : '缺失'}`);

const cos = new COS({ SecretId: secretId, SecretKey: secretKey });

function p<T>(fn: (params: any, cb: (err: any, data: T) => void) => void, params: any, label: string): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      console.log(`[probe] ⚠️ ${label} 超时（10s 无响应）`);
      resolve();
    }, 10000);
    try {
      fn.call(cos, params, (err: any, data: T) => {
        clearTimeout(timer);
        if (err) {
          console.log(`[probe] ❌ ${label} 失败：${JSON.stringify(err).slice(0, 300)}`);
        } else {
          console.log(`[probe] ✅ ${label} 成功`);
        }
        resolve();
      });
    } catch (e: any) {
      clearTimeout(timer);
      console.log(`[probe] 💥 ${label} 抛异常：${e?.message ?? e}`);
      resolve();
    }
  });
}

async function main(): Promise<void> {
  await p(cos.headBucket, { Bucket: OLD_BUCKET, Region: REGION }, 'headBucket 旧桶');
  await p(cos.headBucket, { Bucket: NEW_BUCKET, Region: REGION }, 'headBucket 新桶');
  await p(
    cos.getBucket,
    { Bucket: OLD_BUCKET, Region: REGION, MaxKeys: 5 },
    'getBucket 旧桶(前5个对象)'
  );
  console.log('[probe] 诊断完成');
}

main();
