/* 有据上线预告海报 · SVG 生成脚本（1080×1920 × 4）
 * 运行：NODE_PATH=workspace/node_modules node gen-posters.js
 */
const fs = require('fs');
const path = require('path');

const SERIF = 'Songti SC, Noto Serif SC, serif';
const SANS = 'PingFang SC, Noto Sans SC, "Helvetica Neue", sans-serif';
const NUM = '"Helvetica Neue", Arial, sans-serif';
const PAPER = '#FAFAFA', SURFACE = '#FFFFFF', S2 = '#F2F2F5';
const INK = '#0D0F12', GRAY = '#6E6E73', GRAY2 = '#AEAEB2', LINE = '#E5E5EA';
const BLUE = '#1677FF';
const W = 1080, H = 1920;
const LOGO_DATA = 'data:image/png;base64,' + fs.readFileSync(path.join(__dirname,'有据logo.png')).toString('base64');

function esc(s){ return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function txt(x, y, s, size, opts={}){
  const fw = opts.fw || 400, fam = (opts.fam || SANS).replace(/"/g,'&quot;'), fill = opts.fill || INK;
  const anchor = opts.anchor || 'start';
  const extra = (opts.ls ? ` letter-spacing="${opts.ls}"` : '') + (opts.italic ? ' font-style="italic"' : '');
  return `<text x="${x}" y="${y}" font-family="${fam}" font-size="${size}" font-weight="${fw}" fill="${fill}" text-anchor="${anchor}"${extra}>${esc(s)}</text>`;
}
function rect(x,y,w,h,fill,opts={}){
  const rx = opts.rx!==undefined ? opts.rx : 0, sw = opts.sw||0, sc = opts.sc||'none';
  const dash = opts.dash ? ` stroke-dasharray="${opts.dash}"` : '';
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${sc}" stroke-width="${sw}"${dash}/>`;
}
function line(x1,y1,x2,y2,stroke,w=2){ return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${stroke}" stroke-width="${w}"/>`; }
function circle(cx,cy,r,fill){ return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}"/>`; }
function check(cx,cy,r,color){
  const x = cx, y = cy, s = r*0.55;
  return `<circle cx="${x}" cy="${y}" r="${r}" fill="${color}"/><path d="M${x-s*0.55} ${y} l${s*0.4} ${s*0.5} l${s*0.75} -${s*0.95}" fill="none" stroke="#FFFFFF" stroke-width="${r*0.28}" stroke-linecap="round" stroke-linejoin="round"/>`;
}
function header(tag){
  return `<g>
    <clipPath id="logoClip"><rect x="76" y="78" width="68" height="68" rx="15"/></clipPath>
    <image href="${LOGO_DATA}" x="76" y="78" width="68" height="68" clip-path="url(#logoClip)"/>
    ${txt(166,118,'有据',34,{fw:700,fam:SERIF})}
    ${txt(1004,116,tag,24,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
  </g>`;
}
function eyebrow(y,text){
  return `<g>
    ${line(76,y+4,110,y+4,INK,2)}
    ${txt(126,y,text,26,{fw:600,fam:NUM,fill:GRAY})}
  </g>`;
}
const ICON_HEART = 'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z';
const ICON_STAR = 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z';
const ICON_REPEAT = 'M17 1l4 4-4 4M3 11V9a4 4 0 0 1 4-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 0 1-4 4H3';

function iconGlyph(cx, cy, d){
  return `<g transform="translate(${cx-12},${cy-12})" fill="none" stroke="${INK}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></g>`;
}

/* 社交传播区（替代原 CTA）：卖点标语 + 点赞/收藏/转发三连，纯传播无入口 */
function social(slogan, sub, footEn){
  const acts = [['点赞',ICON_HEART],['收藏',ICON_STAR],['转发',ICON_REPEAT]];
  let actG = '';
  let y = 1696;
  acts.forEach(([label,d])=>{
    actG += `<circle cx="868" cy="${y}" r="22" fill="#FFFFFF" stroke="${LINE}" stroke-width="1.5"/>`;
    actG += iconGlyph(868,y,d);
    actG += txt(900,y+9,label,26,{fill:GRAY});
    y += 70;
  });
  const foot = `<g>
    ${line(76,1860,1004,1860,LINE,1.5)}
    ${txt(76,1896,'© 2026 有据 · 鸿蒙原生理性内容社区',24,{fill:GRAY2})}
    ${txt(1004,1896,footEn,24,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
  </g>`;
  return `<g>
    ${line(76,1640,1004,1640,LINE,1.5)}
    ${txt(76,1732,slogan,50,{fw:900,fam:SERIF})}
    ${txt(76,1804,sub,26,{fw:300,fill:GRAY})}
    ${actG}
    ${foot}
  </g>`;
}
function feedCard(y, tag, title, like, cmt){
  const h = 210;
  return `<g>
    ${rect(76,y,860,h,SURFACE,{rx:26,sw:1.5,sc:LINE})}
    ${circle(140,y+105,38,S2)}
    ${txt(196,y+76,tag,25,{fill:GRAY})}
    ${txt(196,y+128,title,46,{fw:700,fam:SERIF})}
    ${rect(196,y+156,300,14,S2,{rx:7})}
    ${rect(196,y+182,180,14,S2,{rx:7})}
    ${txt(852,y+176,`${like} 赞`,26,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
    ${txt(756,y+176,`${cmt} 评`,26,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
  </g>`;
}
function chipRow(y, items){
  let x = 76; let g = '';
  items.forEach(it=>{
    const wpx = it.length*30 + 60;
    g += rect(x,y,wpx,64,'#FFFFFF',{rx:32,sw:1.5,sc:LINE});
    g += txt(x+wpx/2, y+41, it, 27, {fill:GRAY, anchor:'middle'});
    x += wpx + 18;
  });
  return `<g>${g}</g>`;
}

/* ============ P1 预告主海报 ============ */
function p1(){
  return `<g>
    ${header('P01 · COMING SOON')}
    ${eyebrow(430,'即将上线 · HarmonyOS Next')}
    ${txt(76,560,'真实经验，',108,{fw:900,fam:SERIF})}
    ${txt(76,690,'有据可循。',108,{fw:900,fam:SERIF})}
    ${txt(76,790,'一个有据可查的理性内容社区，',38,{fw:300,fill:GRAY})}
    ${txt(76,842,'上架在即，敬请期待。',38,{fw:300,fill:GRAY})}
    ${feedCard(920,'数码选购 · 测评','蓝牙耳机怎么选？附三轮实测对比','128','32')}
    ${feedCard(1150,'汽车养护 · 避坑','首保别被忽悠，这 4 项根本不用做','356','89')}
    ${chipRow(1400,['测评','避坑','教程','辩论','分享'])}
    ${social('把真话，讲给懂的人听','真实经验，有据可循 · 敬请期待','YOUJU · COMING SOON')}
  </g>`;
}

/* ============ P2 理性 ============ */
function p2(){
  let cards = [['01','测评','优缺点 · 推荐指数'],['02','避坑','踩坑 · 正确做法'],['03','教程','工具 · 步骤'],['04','辩论','A/B 方案投票'],['05','分享','经验 · 见闻']];
  let g='';
  let x=76; cards.forEach(c=>{
    g += rect(x,896,171,192,SURFACE,{rx:20,sw:1.5,sc:LINE});
    g += txt(x+22,942,c[0],26,{fw:700,fam:NUM,fill:GRAY2});
    g += txt(x+22,992,c[1],40,{fw:700,fam:SERIF});
    g += txt(x+22,1048,c[2],22,{fill:GRAY});
    x += 171+18;
  });
  const vote = `<g>
    ${rect(76,1120,928,330,SURFACE,{rx:26,sw:1.5,sc:LINE})}
    ${txt(118,1176,'方案 A：先租后买',34,{fw:700,fam:SERIF})}
    ${txt(886,1176,'DEBATE · 62%',24,{fill:GRAY2,anchor:'end'})}
    ${rect(118,1200,844,18,S2,{rx:9})}
    ${rect(118,1200,523,18,INK,{rx:9})}
    ${txt(118,1290,'方案 B：直接攒首付',34,{fw:700,fam:SERIF})}
    ${txt(886,1290,'DEBATE · 38%',24,{fill:GRAY2,anchor:'end'})}
    ${rect(118,1314,844,18,S2,{rx:9})}
    ${rect(118,1314,321,18,BLUE,{rx:9})}
    ${txt(118,1408,'理性 · 拒绝标题党与爹味说教',26,{fill:GRAY2})}
  </g>`;
  return `<g>
    ${header('P02 · RATIONALITY')}
    ${eyebrow(430,'有据 · 价值观 01 —— 理性')}
    ${txt(76,560,'拒绝标题党，',108,{fw:900,fam:SERIF})}
    ${txt(76,690,'把经验讲清楚。',108,{fw:900,fam:SERIF})}
    ${txt(76,800,'有结构的内容，才配叫「有据」。',38,{fw:300,fill:GRAY})}
    <g>${g}</g>
    ${vote}
    ${chipRow(1490,['五体裁','结构化字段','有图有真相'])}
    ${social('少一点标题党，多一点真话','真实经验，有据可循 · 敬请期待','YOUJU · RATIONALITY')}
  </g>`;
}

/* ============ P3 友善 ============ */
function p3(){
  const q = `<g>
    ${txt(66,1020,'「',300,{fw:900,fam:SERIF,fill:'#ECECEF'})}
    ${txt(226,1020,'」',300,{fw:900,fam:SERIF,fill:'#ECECEF'})}
    ${circle(292,966,11,BLUE)}
  </g>`;
  const rows = `<g>
    ${circle(110,1152,8,GRAY2)}${txt(146,1178,'反对性别对立',56,{fw:700,fam:SERIF})}
    ${circle(110,1248,8,GRAY2)}${txt(146,1274,'拒绝标题党与爹味说教',56,{fw:700,fam:SERIF})}
    ${circle(110,1344,8,BLUE)}${txt(146,1370,'三道内容安全防线',56,{fw:700,fam:SERIF})}
    ${txt(76,1438,'两档社交距离 · 7 类举报理由 · 数据境内可导出可注销',26,{fill:GRAY2})}
  </g>`;
  return `<g>
    ${header('P03 · KINDNESS')}
    ${eyebrow(430,'有据 · 价值观 02 —— 友善')}
    ${txt(76,560,'不喜欢就少推点，',96,{fw:900,fam:SERIF})}
    ${txt(76,676,'拉黑就别再见。',96,{fw:900,fam:SERIF})}
    ${txt(76,778,'体面的社区，边界由你掌控。',38,{fw:300,fill:GRAY})}
    ${q}
    ${rows}
    ${social('不喜欢就少推点，别吵架','真实经验，有据可循 · 敬请期待','YOUJU · KINDNESS')}
  </g>`;
}

/* ============ P4 共创 ============ */
function p4(){
  const perks = [['01','上架第一时间通知'],['02','首发内容抢先看'],['03','你的建议，上线前被采纳'],['04','上线专属「首批用户」标识'],['05','见证社区从 0 到 1']];
  let g=''; let y=900;
  perks.forEach((p,i)=>{
    g += rect(76,y,928,96,SURFACE,{rx:22,sw:1.5,sc:LINE});
    g += txt(112,y+61,p[0],32,{fw:800,fam:NUM,fill:GRAY2});
    g += check(212,y+48,17,INK);
    g += txt(266,y+61,p[1],34,{});
    y += 96+18;
  });
  return `<g>
    ${header('P04 · CO-CREATION')}
    ${eyebrow(430,'有据 · 价值观 03 —— 共创')}
    ${txt(76,560,'把经验，',108,{fw:900,fam:SERIF})}
    ${txt(76,690,'装进口袋。',108,{fw:900,fam:SERIF})}
    ${txt(76,800,'上线在即，先占一个位置。',38,{fw:300,fill:GRAY})}
    <g>${g}</g>
    ${social('好经验，值得被更多人看见','真实经验，有据可循 · 敬请期待','YOUJU · CO-CREATION')}
  </g>`;
}

const posters = { p1, p2, p3, p4 };
const names = { p1:'P1-预告主海报', p2:'P2-理性', p3:'P3-友善', p4:'P4-共创' };
const OUT = path.join(__dirname, 'export');
fs.mkdirSync(OUT, {recursive:true});

(async () => {
  const sharp = require('sharp');
  for (const key of Object.keys(posters)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
      <rect width="${W}" height="${H}" fill="${PAPER}"/>
      <rect width="${W}" height="${H}" fill="url(#g)" opacity="1"/>
      <defs><radialGradient id="g" cx="12%" cy="0%" r="90%">
        <stop offset="0%" stop-color="#0D0F12" stop-opacity="0.035"/>
        <stop offset="60%" stop-color="#0D0F12" stop-opacity="0"/>
      </radialGradient></defs>
      ${posters[key]()}
    </svg>`;
    const svgPath = path.join(OUT, names[key] + '.svg');
    const pngPath = path.join(OUT, names[key] + '.png');
    fs.writeFileSync(svgPath, svg);
    await sharp(Buffer.from(svg)).png().toFile(pngPath);
    console.log('OK', names[key]);
  }
})();
