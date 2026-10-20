// 把本机渲染好的海报与头像上传到 COS。
//
// 为什么不让造数脚本内联上传：图片有 30 多 MB、300 多个对象，上传失败要能单独重跑；
// 而且上传成功后要留一份 uploaded.json，让灌库脚本在写库前确认「封面真的存在」，
// 否则会出现帖子有了、封面 404 的情况，首屏一片灰。
//
// 用法（容器内）
//   node dist/scripts/seed-upload-media.js --dir /tmp/seed-assets
//   node dist/scripts/seed-upload-media.js --dir /tmp/seed-assets --dry

import * as fs from 'fs';
import * as path from 'path';
import COS from 'cos-nodejs-sdk-v5';
import { env } from '../config/env';
import { isValidMediaKey } from '../services/uploadService';

interface Args {
  dir: string;
  dry: boolean;
  concurrency: number;
}

const CONTENT_TYPES: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

function parseArgs(argv: string[]): Args {
  const args: Args = { dir: '', dry: false, concurrency: 6 };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--dir') args.dir = path.resolve(argv[++i] ?? '');
    else if (token === '--dry') args.dry = true;
    else if (token === '--concurrency') args.concurrency = Number(argv[++i] ?? 6);
    else {
      console.error(`未知参数 ${token}`);
      process.exit(2);
    }
  }
  if (!args.dir) {
    console.error('缺少 --dir');
    process.exit(2);
  }
  return args;
}

function walk(dir: string, base: string, out: string[]): void {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, base, out);
    } else if (entry.isFile()) {
      const ext = path.extname(entry.name).toLowerCase();
      if (CONTENT_TYPES[ext]) out.push(path.relative(base, full).split(path.sep).join('/'));
    }
  }
}

function uploadOne(cos: COS, key: string, file: string): Promise<void> {
  const contentType = CONTENT_TYPES[path.extname(file).toLowerCase()] ?? 'application/octet-stream';
  return new Promise((resolve, reject) => {
    cos.putObject(
      {
        Bucket: env.cos.bucket,
        Region: env.cos.region,
        Key: key,
        Body: fs.createReadStream(file),
        ContentType: contentType,
      },
      (err) => {
        if (err) reject(err instanceof Error ? err : new Error(JSON.stringify(err)));
        else resolve();
      },
    );
  });
}

async function uploadWithRetry(cos: COS, key: string, file: string, retries: number): Promise<void> {
  let lastError: unknown = null;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      await uploadOne(cos, key, file);
      return;
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 400 * (attempt + 1)));
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.dir)) {
    console.error(`目录不存在 ${args.dir}`);
    process.exit(2);
  }
  const files: string[] = [];
  walk(args.dir, args.dir, files);
  // 目录里的相对路径就是 COS key（posts/seed/xxx.jpg、avatars/seed/xxx.png）
  const keys = files;

  const invalid = keys.filter((key) => !isValidMediaKey(key));
  if (invalid.length > 0) {
    console.error('以下 key 不符合媒体引用规范（必须以 posts/ 或 avatars/ 开头）');
    invalid.slice(0, 10).forEach((key) => console.error(`  ${key}`));
    process.exit(2);
  }

  console.log(`待上传 ${keys.length} 个对象，目录 ${args.dir}`);
  if (args.dry) {
    keys.slice(0, 10).forEach((key) => console.log(`  ${key}`));
    console.log('预演结束，未上传');
    return;
  }

  if (!env.cos.secretId || !env.cos.secretKey || !env.cos.bucket || !env.cos.region) {
    console.error('COS 凭据不完整，无法上传');
    process.exit(1);
  }
  const cos = new COS({ SecretId: env.cos.secretId, SecretKey: env.cos.secretKey });
  const done: string[] = [];
  let cursor = 0;
  let failed = 0;

  const worker = async (): Promise<void> => {
    for (;;) {
      const index = cursor;
      cursor += 1;
      if (index >= keys.length) return;
      const key = keys[index];
      const file = path.join(args.dir, files[index]);
      try {
        await uploadWithRetry(cos, key, file, 2);
        done.push(key);
      } catch (error) {
        failed += 1;
        console.error(`  上传失败 ${key} ${(error as Error).message}`);
      }
      if (done.length % 25 === 0 && done.length > 0) {
        console.log(`  进度 ${done.length}/${keys.length}`);
      }
    }
  };

  const workers: Promise<void>[] = [];
  for (let i = 0; i < Math.max(1, args.concurrency); i += 1) workers.push(worker());
  await Promise.all(workers);

  const reportPath = path.join(args.dir, 'uploaded.json');
  fs.writeFileSync(reportPath, JSON.stringify({ keys: done, failed, at: new Date().toISOString() }, null, 2));
  console.log(`上传完成 ${done.length} 个，失败 ${failed} 个，清单 ${reportPath}`);
  if (failed > 0) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
