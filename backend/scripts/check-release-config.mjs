import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const shareSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/utils/share.ets'), 'utf8');
const shareBase = shareSource.match(/const SHARE_BASE: string = '([^']+)'/)?.[1] ?? '';
const externalShareEnabled = shareSource.match(/export const EXTERNAL_SHARE_ENABLED: boolean = (true|false);/)?.[1] === 'true';

if (!externalShareEnabled) {
  console.log('Release configuration check passed: external sharing is disabled.');
} else if (!/^https:\/\//.test(shareBase) || shareBase === 'https://youju.app') {
  throw new Error('SHARE_BASE 仍是占位值；必须替换为已验证的生产分享域名。');
} else {
  console.log('Release configuration check passed.');
}
