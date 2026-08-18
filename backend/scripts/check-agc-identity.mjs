import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '../..');
const rawfile = JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/rawfile/agconnect-services.json'), 'utf8'));
const moduleJson = fs.readFileSync(path.join(root, 'entry/src/main/module.json5'), 'utf8');
const moduleClientId = moduleJson.match(/"name"\s*:\s*"client_id"\s*,\s*"value"\s*:\s*"([^"]+)"/)?.[1] ?? '';

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(name + ' 必须由受保护的 CI 变量提供');
  return value;
}

function equal(name, actual, expected) {
  if (actual !== expected) throw new Error(name + ' 不一致');
}

equal('package_name', rawfile.client?.package_name, required('AGC_PACKAGE_NAME'));
equal('AGC app_id', rawfile.client?.app_id, required('AGC_APP_ID'));
equal('AGC oauth_client_id', rawfile.oauth_client?.client_id, required('AGC_OAUTH_CLIENT_ID'));
equal('AGC client_id', rawfile.client?.client_id, required('AGC_CONFIG_CLIENT_ID'));
equal('Account Kit client_id', moduleClientId, required('HUAWEI_CLIENT_ID'));
console.log('AGC Release identity check passed.');
