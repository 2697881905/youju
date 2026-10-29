// 深色模式图标审计（缺失方向）v2：渲染 currentColor SVG 却没挂 .fillColor 的 Image 站点
// v1 只匹配「整行仅 Image(arg)」，漏掉同行链式写法（实测 84 站点里 68 个是同行链式）——已修正。
const fs = require('fs'), path = require('path');
const RES = 'entry/src/main/resources/base/media';
const ETS = 'entry/src/main/ets';

const cur = new Set();
for (const f of fs.readdirSync(RES)) {
  if (!f.endsWith('.svg')) continue;
  if (/currentColor/.test(fs.readFileSync(path.join(RES, f), 'utf8'))) cur.add(f.replace(/\.svg$/, ''));
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out); else if (e.name.endsWith('.ets')) out.push(p);
  }
  return out;
}
const files = walk(ETS);

// 标识符 -> 候选图标名（@Prop/字段默认值、注册表 key、iconRes 字段）
const ident = new Map();
function addIdent(name, icon) {
  if (!cur.has(icon)) return;
  if (!ident.has(name)) ident.set(name, new Set());
  ident.get(name).add(icon);
}
// 函数 -> 它可能返回的图标名（resolveActionIcon / settingsIcon / tagIcon / notifIconRes 等）
const fnIcons = new Map();
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  for (const m of src.matchAll(/(\w+)\s*(?::\s*Resource)?\s*=\s*\$r\('app\.media\.(\w+)'\)/g)) addIdent(m[1], m[2]);
  for (const m of src.matchAll(/\[\s*'(\w+)'\s*,\s*\$r\('app\.media\.(\w+)'\]/g)) addIdent(m[1], m[2]);
  for (const m of src.matchAll(/iconRes:\s*\$r\('app\.media\.(\w+)'/g)) addIdent('iconRes', m[1]);
  // 函数体内 return 的图标集合
  for (const fm of src.matchAll(/(?:export\s+)?function\s+(\w+)\s*\([^)]*\)\s*:\s*Resource\s*\{([\s\S]*?)\n\}/g)) {
    const set = new Set();
    for (const r of fm[2].matchAll(/\$r\('app\.media\.(\w+)'\)/g)) if (cur.has(r[1])) set.add(r[1]);
    if (set.size) fnIcons.set(fm[1], set);
  }
}
// 注册表函数（switch/map 查表）无法从单个函数体拿到全部值，用全文件兜底
const allRegistry = new Set();
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  if (/actionIcons|settingsIcons|tagIcons/.test(f)) {
    for (const m of src.matchAll(/\$r\('app\.media\.(\w+)'\)/g)) if (cur.has(m[1])) allRegistry.add(m[1]);
  }
}

function iconsForArg(arg) {
  const set = new Set();
  for (const r of arg.matchAll(/\$r\('app\.media\.(\w+)'\)/g)) if (cur.has(r[1])) set.add(r[1]);
  if (set.size) return set;
  const fm = arg.match(/^\s*(\w+)\(/);            // Image(someFn(x))
  if (fm) {
    if (fnIcons.has(fm[1])) for (const v of fnIcons.get(fm[1])) set.add(v);
    if (/resolveActionIcon|settingsIcon|tagIcon|notifIcon/i.test(fm[1])) for (const v of allRegistry) set.add(v);
    if (set.size) return set;
  }
  const key = arg.replace(/^this\./, '').replace(/\[.*$/, '').replace(/\(.*$/, '').trim();
  if (ident.has(key)) for (const v of ident.get(key)) set.add(v);
  return set;
}

// 从 Image( 出现的行开始，按括号深度取完整修饰符链
// 链尾判定必须跳过空行与注释行：本项目常在两个修饰符之间插一段说明注释，
// 把「下一行不以 . 开头」直接当终止符会在注释处截断，把已挂 fillColor 的站点误报成缺失。
function nextChainLine(lines, j) {
  for (let k = j + 1; k < lines.length; k++) {
    const l = lines[k];
    if (/^\s*$/.test(l) || /^\s*\/\//.test(l) || /^\s*\*/.test(l)) continue;
    return /^\s*\./.test(l) ? l : null;
  }
  return null;
}
function chainFrom(lines, i, col) {
  let depth = 0, started = false; const out = [];
  for (let j = i; j < lines.length && j < i + 140; j++) {
    const l = lines[j];
    let k = 0;
    while (k < l.length) {
      if (j === i && k < col) { k++; continue; }
      const ch = l[k];
      if ('({['.includes(ch)) { depth++; started = true; }
      else if (')}]'.includes(ch)) depth--;
      k++;
    }
    out.push(l);
    if (!started || depth > 0) continue;
    if (nextChainLine(lines, j) === null) break;
  }
  return out.join('\n');
}

const hits = [];
for (const f of files) {
  const lines = fs.readFileSync(f, 'utf8').split('\n');
  lines.forEach((l, i) => {
    let idx = l.indexOf('Image(');
    if (idx < 0) return;
    if (/^\s*\/\//.test(l)) return;
    do {
      const rest = l.slice(idx + 6);
      // Image 的左括号已被 indexOf 消费，初值记 1，否则嵌套调用会在内层闭括号处截断
      let d = 1, end = -1;
      for (let k = 0; k < rest.length; k++) {
        if (rest[k] === '(') d++;
        else if (rest[k] === ')') { d--; if (d === 0) { end = k; break; } }
      }
      if (end < 0) break;
      const arg = rest.slice(0, end);
      const icons = iconsForArg(arg);
      if (icons.size) {
        const ch = chainFrom(lines, i, idx);
        if (!/\.fillColor\s*\(/.test(ch)) hits.push({ file: f, line: i + 1, arg, icons: [...icons].join(',') });
      }
      break;
    } while (false);
  });
}
console.log('=== 渲染 currentColor 图标但缺 .fillColor 的站点 ===');
for (const h of hits) console.log(`  ${h.file}:${h.line} | Image(${h.arg.trim()}) | 候选 ${h.icons.split(',').length} 个`);
console.log(`共 ${hits.length} 处`);
