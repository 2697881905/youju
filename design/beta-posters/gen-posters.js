/* 有据内测招募海报 · SVG 生成脚本（1080×1920 × 4）
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
    ${txt(76,118,'「」',44,{fw:900,fam:SERIF})}
    ${circle(148,86,6,BLUE)}
    ${txt(196,118,'有据',34,{fw:700,fam:SERIF})}
    ${txt(1004,116,tag,24,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
  </g>`;
}
function eyebrow(y,text){
  return `<g>
    ${line(76,y+4,110,y+4,INK,2)}
    ${txt(126,y,text,26,{fw:600,fam:NUM,fill:GRAY})}
  </g>`;
}
function cta(posterNo, footEn, quotaBlue){
  const noteColor = quotaBlue ? {b:BLUE} : {b:INK};
  const btn = `<g>
    ${rect(76,1644,520,88,BLUE,{rx:44})}
    ${txt(204,1703,'申请加入内测',38,{fw:500})}
    ${txt(646,1705,'→',34,{fw:600,fam:NUM,fill:'#FFFFFF'})}
  </g>`;
  const note = `<g>
    ${txt(76,1772,'首批限 ',27,{fill:GRAY})}
    ${txt(176,1772,'500',27,{fw:800,fam:NUM,fill:noteColor.b})}
    ${txt(252,1772,' 名 · 报名截止 8 月 31 日',27,{fill:GRAY})}
  </g>`;
  const qr = `<g>
    ${rect(826,1620,178,178,'#FFFFFF',{rx:22,sw:2.5,sc:GRAY2,dash:'10 10'})}
    ${txt(915,1694,'内测申请码',23,{fill:GRAY2,anchor:'middle'})}
    ${txt(915,1726,'二维码占位',23,{fill:GRAY2,anchor:'middle'})}
  </g>`;
  const foot = `<g>
    ${line(76,1840,1004,1840,LINE,1.5)}
    ${txt(76,1876,'© 2026 有据 · 鸿蒙原生理性内容社区',24,{fill:GRAY2})}
    ${txt(1004,1876,footEn,24,{fw:600,fam:NUM,fill:GRAY2,anchor:'end'})}
  </g>`;
  return `<g>${btn}${note}${qr}${foot}</g>`;
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

/* ============ P1 招募主海报 ============ */
function p1(){
  return `<g>
    ${header('P01 · BETA RECRUIT')}
    ${eyebrow(430,'首批内测招募 · HarmonyOS Next')}
    ${txt(76,560,'真实经验，',108,{fw:900,fam:SERIF})}
    ${txt(76,690,'有据可循。',108,{fw:900,fam:SERIF})}
    ${txt(76,790,'一个有据可查的理性内容社区，',38,{fw:300,fill:GRAY})}
    ${txt(76,842,'等你来，把它变成想要的样子。',38,{fw:300,fill:GRAY})}
    ${feedCard(920,'数码选购 · 测评','蓝牙耳机怎么选？附三轮实测对比','128','32')}
    ${feedCard(1150,'汽车养护 · 避坑','首保别被忽悠，这 4 项根本不用做','356','89')}
    ${chipRow(1400,['测评','避坑','教程','辩论','分享'])}
    ${cta('P1','YOUJU · REAL EXPERIENCE',false)}
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
    ${cta('P2','YOUJU · RATIONALITY',false)}
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
    ${cta('P3','YOUJU · KINDNESS',false)}
  </g>`;
}

/* ============ P4 共创 ============ */
function p4(){
  const perks = [['01','抢先体验鸿蒙原生全功能'],['02','专属「内测先锋」身份标识'],['03','直通产品团队的反馈通道'],['04','内测专属活动与内容'],['05','限量电子勋章，见证从 0 到 1']];
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
    ${txt(76,560,'第一批，',108,{fw:900,fam:SERIF})}
    ${txt(76,690,'值得被听见。',108,{fw:900,fam:SERIF})}
    ${txt(76,800,'内测，就是一起把它做成想要的样子。',38,{fw:300,fill:GRAY})}
    <g>${g}</g>
    ${cta('P4','YOUJU · CO-CREATION',true)}
  </g>`;
}

const posters = { p1, p2, p3, p4 };
const names = { p1:'P1-招募主海报', p2:'P2-理性', p3:'P3-友善', p4:'P4-共创' };
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
