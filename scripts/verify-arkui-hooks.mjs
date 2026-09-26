#!/usr/bin/env node
/**
 * ArkUI 生命周期钩子 / 页内覆盖层的静态检查。
 *
 * 为什么需要（2026-09-27 真实事故）：
 *   双壳架构下（pages/XxxPage.ets 是 @Entry，pages/XxxDestination.ets 是 NavDestination，
 *   两者共享 pages/XxxView.ets 这个 @Component），有人把返回拦截写在了共享视图上：
 *
 *     // ChatView.ets —— 写在 @Component 里
 *     onBackPress(): boolean { ...关闭查看器... return true; }
 *
 *   但 ArkUI 的 `onBackPress` **只对 @Entry 组件生效**，共享视图两者都不是，
 *   这段逻辑从来没被调用过 —— 表现就是「看图后返回手势直接退出页面」，
 *   而代码里还留着「已经处理好了」的注释，排查时极具误导性。
 *
 * 两条规则：
 *   [错误]  @Entry 专属钩子（onBackPress）出现在非 @Entry 的 struct 里 → 死代码，必须处理
 *   [待决策] onPageShow / onPageHide 同理，但启用它会改变行为（如聊天页会闪一下 Loading
 *            并强制滚到底），需要人做决定，因此只报告不算错误
 *   [错误]  渲染了全屏覆盖层组件（ImageViewer / VideoViewer）却没登记返回守卫
 *            （utils/overlayBackGuard）→ 返回手势会直接退出宿主页
 *
 * 运行：node scripts/verify-arkui-hooks.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const ETS_ROOT = path.join(ROOT, 'entry/src/main/ets');

// @Entry 专属：写到别处就是死代码
const ENTRY_ONLY_HARD = ['onBackPress'];
// @Entry 专属但会影响行为，需人判断
const ENTRY_ONLY_SOFT = ['onPageShow', 'onPageHide'];
// 页内全屏覆盖层组件：渲染它们的宿主必须登记返回守卫
const OVERLAY_COMPONENTS = ['ImageViewer', 'VideoViewer'];

const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      walk(p);
    } else if (/\.(ets|ts)$/.test(e.name)) {
      files.push(p);
    }
  }
})(ETS_ROOT);

const errors = [];
const pending = [];

for (const file of files) {
  const rel = path.relative(ROOT, file);
  const lines = fs.readFileSync(file, 'utf8').split('\n');

  // —— 收集所有 struct 的「装饰器 + 起止行」——
  const structs = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(?:export\s+)?struct\s+([A-Za-z0-9_]+)\s*\{/);
    if (!m) {
      continue;
    }
    const decorators = [];
    let j = i - 1;
    while (j >= 0 && /^\s*@[A-Za-z]/.test(lines[j])) {
      decorators.push(lines[j].trim());
      j -= 1;
    }
    // 本工程 struct 的收尾 } 一律在行首（列 0），据此界定 body
    let end = lines.length - 1;
    for (let k = i + 1; k < lines.length; k++) {
      if (lines[k] === '}') {
        end = k;
        break;
      }
    }
    structs.push({ name: m[1], from: i, to: end, decorators: decorators, isEntry: decorators.includes('@Entry') });
  }

  const enclosing = (lineNo) => {
    for (const s of structs) {
      if (lineNo > s.from && lineNo <= s.to) {
        return s;
      }
    }
    return null;
  };

  // —— 规则 1 / 2：@Entry 专属钩子 ——
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^\s*(onBackPress|onPageShow|onPageHide)\s*\(/);
    if (!m) {
      continue;
    }
    const hook = m[1];
    const s = enclosing(i);
    if (s === null || s.isEntry) {
      continue;
    }
    const where = rel + ':' + (i + 1) + '  ' + s.name + '.' + hook + '()';
    if (ENTRY_ONLY_HARD.includes(hook)) {
      errors.push(where + ' —— ' + hook + ' 只对 @Entry 组件生效，而 ' + s.name + ' 是 @Component，这段逻辑不会被调用');
    } else if (ENTRY_ONLY_SOFT.includes(hook)) {
      pending.push(where + ' —— 同上，' + hook + ' 不会触发；若启用需确认行为副作用');
    }
  }

  // —— 规则 3：渲染覆盖层必须登记返回守卫 ——
  const src = lines.join('\n');
  for (const comp of OVERLAY_COMPONENTS) {
    // 组件实例化形如 `ComponentName({` 或 `<ComponentName(`
    const used = new RegExp('(?:^|[^A-Za-z0-9_])' + comp + '\\s*\\(', 'm').test(src);
    if (!used) {
      continue;
    }
    const guarded = /utils\/overlayBackGuard/.test(src);
    if (!guarded) {
      errors.push(rel + ' —— 渲染了 ' + comp + ' 但没有登记返回守卫（import utils/overlayBackGuard），返回手势会直接退出宿主页');
    }
  }
}

console.log('');
if (errors.length > 0) {
  console.log('[错误] ' + errors.length + ' 项：');
  for (const e of errors) {
    console.log('  x ' + e);
  }
} else {
  console.log('[错误] 0 项 —— @Entry 专属钩子都在 @Entry 上，覆盖层宿主都登记了返回守卫');
}
if (pending.length > 0) {
  console.log('');
  console.log('[待决策] ' + pending.length + ' 项（死代码，但不改行为，故不判失败）：');
  for (const p of pending) {
    console.log('  ! ' + p);
  }
}
console.log('');
process.exit(errors.length === 0 ? 0 : 1);
