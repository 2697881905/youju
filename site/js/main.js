/* ============================================================
   有据官网动效 · GSAP + ScrollTrigger + Flip + Lenis
   - Lenis 惯性平滑滚动（桌面滚轮丝滑；触屏保持原生）
   - 首屏加载编排：导航 → eyebrow → 副标 → 按钮 → 设备
   - 入场 reveal（双向循环）、标题逐字揭示
   - 图库式核心能力：条目切换 Flip 共享转场 + 选中胶囊跟随
   - 截图点击放大（Flip）
   - 指针灵动：设备 3D 倾斜、主按钮磁吸（仅精确指针）
   - 降级链路：head 内联脚本仅在「非 reduced-motion」时挂 js-motion 类；
     GSAP 缺失或 reduce 时此处移除该类，内容零动画但完整可读。
   ============================================================ */
(function(){
  'use strict';
  var root = document.documentElement;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hasGSAP = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';

  /* ---------- 导航：滚动玻璃底 + 黑色章节反色（原生监听，不依赖 GSAP） ---------- */
  var nav = document.getElementById('nav');
  var scrolled = false, inDark = false;
  function syncNav(){
    nav.classList.toggle('is-scrolled', scrolled);
    nav.classList.toggle('nav-invert', inDark);
  }
  window.addEventListener('scroll', function(){
    scrolled = window.scrollY > 40;
    syncNav();
  }, {passive:true});
  if('IntersectionObserver' in window){
    var darkZones = document.querySelectorAll('.harmony, .download, .footer');
    var io = new IntersectionObserver(function(entries){
      inDark = entries.some(function(e){ return e.isIntersecting; });
      syncNav();
    }, {rootMargin:'0px 0px -92% 0px'});
    darkZones.forEach(function(z){ io.observe(z); });

    /* 演示视频：进入视口才播放，离开即暂停（节省流量与性能） */
    var vids = document.querySelectorAll('.device-video');
    if(vids.length){
      var vio = new IntersectionObserver(function(entries){
        entries.forEach(function(e){
          if(e.isIntersecting){ if(!reduce) e.target.play().catch(function(){}); }
          else{ e.target.pause(); }
        });
      }, {threshold:.25});
      vids.forEach(function(v){ vio.observe(v); });
    }
  }

  /* ---------- 降级：无 GSAP 或用户偏好减少动效 ---------- */
  if(!hasGSAP || reduce){
    root.classList.remove('js-motion');
    document.querySelectorAll('.device-video').forEach(function(v){
      v.removeAttribute('autoplay');
      v.pause();
    });
    return;
  }

  gsap.registerPlugin(ScrollTrigger);
  var hasFlip = typeof window.Flip !== 'undefined';
  if(hasFlip){ gsap.registerPlugin(Flip); }
  var hasScramble = typeof window.ScrambleTextPlugin !== 'undefined';
  if(hasScramble){ gsap.registerPlugin(ScrambleTextPlugin); }

  /* ---------- 1. Lenis 惯性平滑滚动（自托管 js/vendor/lenis.min.js） ---------- */
  var lenis = null;
  if(typeof window.Lenis !== 'undefined'){
    lenis = new Lenis({duration:1.15, smoothWheel:true});
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add(function(time){ lenis.raf(time * 1000); });
    gsap.ticker.lagSmoothing(0);
    root.classList.add('has-lenis');
    /* 页内锚点改走 lenis.scrollTo（带导航高度补偿） */
    document.querySelectorAll('a[href^="#"]').forEach(function(a){
      a.addEventListener('click', function(e){
        e.preventDefault();
        var href = a.getAttribute('href');
        if(href.length > 1){
          var t = document.querySelector(href);
          if(t){ lenis.scrollTo(t, {offset:-72}); }
        }else{
          lenis.scrollTo(0);
        }
      });
    });
  }
  function smoothTo(el, center){
    if(!el) return;
    if(lenis){
      var offset = center ? -(window.innerHeight - el.offsetHeight) / 2 : -72;
      lenis.scrollTo(el, {offset:offset});
    }else{
      el.scrollIntoView({behavior:'smooth', block:center ? 'center' : 'start'});
    }
  }

  /* ---------- 1.5 阅读进度卷轴线（2px，滚动进度驱动） ---------- */
  var progress = document.querySelector('.progress');
  if(progress){
    gsap.to(progress, {scaleX:1, ease:'none', scrollTrigger:{start:0, end:'max', scrub:.3}});
  }

  /* ---------- 2. 首屏加载编排 + 氛围光斑 + 首屏截图微视差 ---------- */
  gsap.timeline({defaults:{ease:'power3.out'}})
    .fromTo('.nav', {y:-18, autoAlpha:0}, {y:0, autoAlpha:1, duration:.7}, .05)
    .fromTo('.hero__copy .eyebrow', {y:26, autoAlpha:0}, {y:0, autoAlpha:1, duration:.8}, .18)
    .fromTo('.hero__sub', {y:26, autoAlpha:0}, {y:0, autoAlpha:1, duration:.8}, .38)
    .fromTo('.hero__actions', {y:22, autoAlpha:0}, {y:0, autoAlpha:1, duration:.8}, .5)
    .fromTo('.hero__visual', {y:52, autoAlpha:0, scale:.965}, {y:0, autoAlpha:1, scale:1, duration:1.1}, .32);

  var glow = document.querySelector('.hero__glow');
  if(glow){
    /* 漂移：y 走无限循环；滚动：yPercent 走 scrub（两者不同属性，可叠加） */
    gsap.to(glow, {x:46, y:-34, scale:1.12, duration:8.5, ease:'sine.inOut', repeat:-1, yoyo:true});
    gsap.to(glow, {yPercent:26, ease:'none',
      scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.6}});
  }
  /* 首屏退场分层（三层深度）：光斑滞后下坠(yPercent +26) < 文案(-16) < 设备(-32) */
  gsap.fromTo('.hero__copy', {yPercent:0}, {yPercent:-16, ease:'none',
    scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:true}});
  gsap.fromTo('.hero__visual', {yPercent:0}, {yPercent:-32, ease:'none',
    scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:true}});

  /* ---------- 3. 标题逐字揭示（SplitText mask 裁切 + 六层：路径分组大幅差异化 / 活错峰 / 丝滑收敛 / 性能开关） ---------- */
  /* 拆分统一在 document.fonts.ready 之后执行（避免字体加载后换行/度量错位）；
     SplitText 原生保留嵌套元素（hero 渐变 span）与 <br> 分行。 */
  var hasSplit = typeof window.SplitText !== 'undefined';
  function initTitleSplits(){
    if(!hasSplit) return;

    /* 移动端分档：粗指针 rotateY/x/z 幅度砍半（K=0.5），模糊上限 12px */
    var coarse = window.matchMedia('(pointer:coarse)').matches;
    var K = coarse ? 0.5 : 1;
    var blurMax = coarse ? 12 : 24;

    /* CustomEase silk 三曲线（前段猛后段缓）；插件缺失时回退内置缓动池。
       initTitleSplits 仅在 fonts.ready 后执行一次；create 重复调用为静默覆盖，无重复注册风险 */
    var EASES;
    if(typeof window.CustomEase !== 'undefined'){
      gsap.registerPlugin(CustomEase);
      CustomEase.create('silk', 'M0,0 C0.16,1 0.3,1 1,1');
      CustomEase.create('silkSoft', 'M0,0 C0.2,0.75 0.4,1 1,1');
      CustomEase.create('silkBack', 'M0,0 C0.34,1.56 0.64,1 1,1');
      EASES = ['silk', 'silkSoft', 'silkBack'];
    }else{
      EASES = ['expo.out', 'power4.out', 'power3.out'];
    }

    /* from 全函数化（每次触发重新抽签，绝不与写死的 to 混用）：
       i%3 路径分组 —— 0 下翻 / 1 侧甩 / 2 深推；其余维度统一范围随机 */
    function fromVars(){
      return {
        yPercent:function(i){ return (i % 3) === 0 ? gsap.utils.random(140, 220) : gsap.utils.random(80, 150); },
        rotationX:function(i){ return (i % 3) === 0 ? gsap.utils.random(-180, -90) : gsap.utils.random(-110, -30); },
        rotationY:function(i){ return (i % 3) === 1 ? (i % 2 ? 1 : -1) * gsap.utils.random(40, 90) * K : gsap.utils.random(-25, 25); },
        rotate:function(){ return gsap.utils.random(-35, 35); },
        x:function(i){ return (i % 3) === 1 ? (i % 2 ? 1 : -1) * gsap.utils.random(60, 120) * K : gsap.utils.random(-45, 45); },
        z:function(i){
          var g = i % 3;
          return gsap.utils.random((g === 2 ? -600 : -180) * K, (g === 2 ? -260 : -40) * K);
        },
        scale:function(i){ return (i % 3) === 2 ? gsap.utils.random(0.3, 0.6) : gsap.utils.random(0.55, 1.4); },
        filter:function(){ return 'blur(' + gsap.utils.random(6, blurMax).toFixed(1) + 'px)'; },
        opacity:0
      };
    }

    /* 首屏与章节标题：逐字翻入（六层：大幅差异化姿态 / 活错峰 / 路径分组 / 丝滑收敛 / 入场后仍活着 / 性能开关） */
    document.querySelectorAll('.hero__title, h2[data-reveal], h3[data-reveal]').forEach(function(el){
      el.removeAttribute('data-reveal');
      SplitText.create(el, {
        type:'chars', mask:'chars', charsClass:'st-char',
        onSplit:function(self){
          /* 第一~三层：初始态 from 函数化抽签；性能开关随初始态一并落位
             （透视逐字自带 —— 容器 perspective 穿不透 mask 层，char 是孙级） */
          var fromSet = fromVars();
          fromSet.transformOrigin = '50% 100%';
          fromSet.transformPerspective = 800;
          fromSet.force3D = true;
          fromSet.backfaceVisibility = 'hidden';
          fromSet.willChange = 'transform, opacity, filter';
          gsap.set(self.chars, fromSet);
          gsap.set(el, {opacity:1, transformStyle:'preserve-3d'});
          var enterTl = null;
          ScrollTrigger.create({
            trigger:el, start:'top 88%',
            onEnter:function(){
              /* 逐字独立补间：duration 1.2~2.2 随机、ease 从 silk 池随机抽取、
                 时间位置随机摆放在 1.8s 窗口内（等价 stagger{amount:1.8, from:'random'}）；
                 to 九值全部写死 —— 终点零随机，丝滑收敛；每字落位即释放 will-change */
              if(enterTl){ enterTl.kill(); }
              gsap.set(self.chars, {willChange:'transform, opacity, filter'});
              enterTl = gsap.timeline({delay:0.2});
              self.chars.forEach(function(c){
                enterTl.to(c, {
                  yPercent:0, rotationX:0, rotationY:0, rotate:0, x:0, z:0, scale:1,
                  filter:'blur(0px)', opacity:1,
                  duration:gsap.utils.random(1.2, 2.2),
                  ease:gsap.utils.random(EASES),
                  overwrite:'auto',
                  onComplete:function(){ c.style.willChange = 'auto'; }
                }, gsap.utils.random(0, 1.8));
              });
            },
            onLeaveBack:function(){
              /* 双向循环：滚回时回到新一轮随机姿态（fromVars 重新抽签；from 随机 / to 固定原则不变） */
              if(enterTl){ enterTl.kill(); enterTl = null; }
              gsap.to(self.chars, Object.assign(fromVars(), {
                duration:.55, ease:'power2.in', overwrite:'auto',
                stagger:{amount:.5, from:'random'},
                onComplete:function(){ gsap.set(self.chars, {willChange:'auto'}); }
              }));
            }
          });
          /* 第五层-滚动：标题滚离视口时的 scrub 收场（作用在 el 容器，与 char 动画不同目标不冲突） */
          gsap.to(el, {
            yPercent:-25, scale:.94, opacity:.5, ease:'none',
            scrollTrigger:{trigger:el, start:'top top', end:'bottom top', scrub:1}
          });
          /* 第五层-鼠标：靠近光标的字符轻微抬起（仅精确指针；y(px) 与入场的 yPercent 不同属性可并存） */
          if(window.matchMedia('(pointer:fine)').matches){
            var charRects = null;
            el.addEventListener('mouseenter', function(){
              charRects = self.chars.map(function(c){ return c.getBoundingClientRect(); });
            });
            el.addEventListener('mousemove', function(e){
              if(!charRects) return;
              self.chars.forEach(function(c, i){
                var r = charRects[i];
                var d = Math.abs(e.clientX - (r.left + r.width / 2)) / (r.width * 3 + 1);
                var influence = Math.max(0, 1 - d);
                gsap.to(c, {y:-14 * influence, duration:.35, ease:'power2.out', overwrite:'auto'});
              });
            });
            el.addEventListener('mouseleave', function(){
              charRects = null;
              gsap.to(self.chars, {y:0, duration:.5, ease:'power3.out', overwrite:'auto'});
            });
          }
        }
      });
    });

    /* 多行段落：逐行 mask 揭示（鸿蒙章节两段描述，power4.out 拉丝感） */
    document.querySelectorAll('.hkit__desc').forEach(function(el){
      SplitText.create(el, {
        type:'lines', mask:'lines', linesClass:'st-line',
        onSplit:function(self){
          gsap.set(self.lines, {yPercent:110, opacity:0});
          ScrollTrigger.create({
            trigger:el, start:'top 85%',
            onEnter:function(){
              gsap.to(self.lines, {yPercent:0, opacity:1, duration:1, ease:'power4.out', stagger:.1, overwrite:true});
            },
            onLeaveBack:function(){
              gsap.to(self.lines, {yPercent:110, opacity:0, duration:.4, ease:'power2.in', stagger:.05, overwrite:true});
            }
          });
        }
      });
    });
  }
  if(hasSplit){
    if(document.fonts && document.fonts.ready){
      document.fonts.ready.then(initTitleSplits);
    }else{
      initTitleSplits();
    }
  }else{
    /* SplitText 缺失：解除首屏标题门控；h2/h3 保留 data-reveal 走普通淡入 */
    gsap.set('.hero__title', {opacity:1});
    gsap.utils.toArray('h2[data-reveal], h3[data-reveal]').forEach(function(el){
      el.removeAttribute('data-reveal');
      gsap.set(el, {opacity:1});
    });
  }

  /* ---------- 3.5 宣言逐字点亮（GSAP 官网 highlight-word 同款：scrub 双向） ---------- */
  document.querySelectorAll('[data-illuminate]').forEach(function(el){
    var chars = [];
    var frag = document.createDocumentFragment();
    Array.prototype.slice.call(el.childNodes).forEach(function(n){
      var em = n.nodeType === 1 && n.tagName === 'EM';
      Array.from(n.textContent || '').forEach(function(c){
        if(/[，。、！？：；]/.test(c)){ frag.appendChild(document.createTextNode(c)); return; }  /* 标点不拆，避免行首标点 */
        if(/\s/.test(c)){ frag.appendChild(document.createTextNode(' ')); return; }
        var s = document.createElement('span');
        s.className = em ? 'il-c il-em' : 'il-c';
        s.textContent = c;
        frag.appendChild(s); chars.push(s);
      });
    });
    el.innerHTML = '';
    el.appendChild(frag);
    gsap.set(chars, {opacity:.13, y:14});
    gsap.to(chars, {opacity:1, y:0, stagger:.07, ease:'none',
      scrollTrigger:{trigger:el, start:'top 78%', end:'top 28%', scrub:.4}});
  });

  /* ---------- 3.6 眉标解码（ScrambleText，GSAP 官网同款文字戏法；插件缺失则跳过） ---------- */
  if(hasScramble){
    gsap.utils.toArray('.section-head .eyebrow').forEach(function(el){
      var finalText = el.textContent;
      ScrollTrigger.create({
        trigger:el, start:'top 88%', once:true,
        onEnter:function(){
          gsap.to(el, {duration:1.1, scrambleText:{text:finalText, chars:'有据可依更好的生活出处结构追问理性分享', speed:.35}});
        }
      });
    });
  }

  /* ---------- 4. 入场 reveal（双向循环，带纵向缩放；H2/H3 由 SplitText 单独接管，不进批量） ---------- */
  var reveals = [];
  document.querySelectorAll('[data-reveal]').forEach(function(el){
    if(el.tagName !== 'H2' && el.tagName !== 'H3'){ reveals.push(el); }
  });
  gsap.set(reveals, {y:36, scale:.985});
  ScrollTrigger.batch(reveals, {
    start:'top 88%',
    onEnter:function(batch){
      gsap.to(batch, {autoAlpha:1, y:0, scale:1, duration:.9, ease:'power3.out', stagger:.08, overwrite:true});
    },
    onLeaveBack:function(batch){
      gsap.to(batch, {autoAlpha:0, y:36, scale:.985, duration:.45, ease:'power2.in', stagger:.04, overwrite:true});
    }
  });

  /* ---------- 5. 滚动视差（分层速率：场景 44 > 鸿蒙 30 > 下载 24）+ Hero 设备呼吸浮动 ---------- */
  [['.scene .device', 44], ['.hkit__stage .device', 30], ['.download__visual .device', 24]].forEach(function(cfg){
    gsap.utils.toArray(cfg[0]).forEach(function(d){
      gsap.fromTo(d, {y:cfg[1]}, {y:-cfg[1], ease:'none',
        scrollTrigger:{trigger:d, start:'top bottom', end:'bottom top', scrub:.5}});
    });
  });
  gsap.to('.hero__visual .device', {y:-11, duration:3.2, ease:'sine.inOut', repeat:-1, yoyo:true});
  /* 大标题横向微漂移（滚动联动 ±1.2%，与逐字揭示分层不冲突） */
  gsap.utils.toArray('.section-head h2').forEach(function(h){
    gsap.fromTo(h, {xPercent:-1.2}, {xPercent:1.2, ease:'none',
      scrollTrigger:{trigger:h, start:'top bottom', end:'bottom top', scrub:true}});
  });

  /* ---------- 6. 指针灵动：设备 3D 倾斜 + 主按钮磁吸（仅精确指针） ---------- */
  if(window.matchMedia('(pointer:fine)').matches){
    gsap.utils.toArray('.hero__visual .device, .scene .device, .download__visual .device').forEach(function(d){
      gsap.set(d, {transformPerspective:900});
      var rx = gsap.quickTo(d, 'rotationX', {duration:.6, ease:'power3.out'});
      var ry = gsap.quickTo(d, 'rotationY', {duration:.6, ease:'power3.out'});
      d.addEventListener('mousemove', function(e){
        var r = d.getBoundingClientRect();
        ry(((e.clientX - r.left) / r.width - .5) * 10);
        rx(-((e.clientY - r.top) / r.height - .5) * 8);
      });
      d.addEventListener('mouseleave', function(){ rx(0); ry(0); });
    });
    document.querySelectorAll('.btn--primary').forEach(function(btn){
      /* 磁吸 */
      var bx = gsap.quickTo(btn, 'x', {duration:.4, ease:'power3.out'});
      var by = gsap.quickTo(btn, 'y', {duration:.4, ease:'power3.out'});
      btn.addEventListener('mousemove', function(e){
        var r = btn.getBoundingClientRect();
        bx((e.clientX - r.left - r.width / 2) * .18);
        by((e.clientY - r.top - r.height / 2) * .3 - 2);
      });
      btn.addEventListener('mouseleave', function(){
        gsap.to(btn, {x:0, y:0, duration:.7, ease:'elastic.out(1,.45)'});
      });
      /* flair：白色圆从指针处扩张铺满（GSAP 官网按钮同款） */
      var flair = document.createElement('span');
      flair.className = 'btn__flair';
      btn.appendChild(flair);
      function flairPos(e){
        var r = btn.getBoundingClientRect();
        flair.style.setProperty('--fx', (e.clientX - r.left) + 'px');
        flair.style.setProperty('--fy', (e.clientY - r.top) + 'px');
      }
      btn.addEventListener('mouseenter', function(e){
        flairPos(e);
        gsap.to(flair, {scale:1, duration:.55, ease:'power3.out', overwrite:true});
      });
      btn.addEventListener('mouseleave', function(e){
        flairPos(e);
        gsap.to(flair, {scale:0, duration:.45, ease:'power3.in', overwrite:true});
      });
    });
    /* 场景卡聚光：光斑圆心跟随指针 */
    document.querySelectorAll('.scene').forEach(function(card){
      card.addEventListener('mousemove', function(e){
        var r = card.getBoundingClientRect();
        card.style.setProperty('--mx', (e.clientX - r.left) + 'px');
        card.style.setProperty('--my', (e.clientY - r.top) + 'px');
      });
    });
  }

  /* ---------- 7. 核心能力图库：条目切换 + 设备屏 Flip 共享转场 + 选中胶囊跟随 ---------- */
  /* 无 GSAP / reduced-motion 时已在上方降级返回：js-motion 类被移除，
     CSS 回退为「四条目 + 四屏全部可见」的静态布局，内容完整可读。 */
  var gallery = document.getElementById('gallery');
  if(gallery){
    var gPanel = gallery.querySelector('.gallery__panel');
    var gMarker = gallery.querySelector('.gallery__marker');
    var gItems = Array.prototype.slice.call(gallery.querySelectorAll('.gallery__item'));
    var gDevices = Array.prototype.slice.call(gallery.querySelectorAll('.gallery__stage .device'));
    var gActive = 0;
    var gBusy = false;
    gallery.classList.add('is-enhanced');

    function gPlaceMarker(animate){
      if(!gMarker || !gItems[gActive]) return;
      var tab = gItems[gActive].querySelector('.gallery__tab');
      var pr = gPanel.getBoundingClientRect();
      var tr = tab.getBoundingClientRect();
      var y = tr.top - pr.top - 8, h = tr.height + 16;
      if(animate){ gsap.to(gMarker, {y:y, height:h, duration:.5, ease:'power3.out'}); }
      else{ gsap.set(gMarker, {y:y, height:h}); }
    }

    function gApply(idx){
      gItems.forEach(function(it, i){
        it.classList.toggle('is-active', i === idx);
        it.querySelector('.gallery__tab').setAttribute('aria-expanded', i === idx ? 'true' : 'false');
      });
      gDevices.forEach(function(d, i){ d.classList.toggle('is-active', i === idx); });
      gActive = idx;
    }

    gItems.forEach(function(item){
      item.querySelector('.gallery__tab').addEventListener('click', function(){
        var idx = parseInt(item.getAttribute('data-idx'), 10);
        if(gBusy || isNaN(idx) || idx === gActive) return;
        var dir = idx > gActive ? 1 : -1;
        var desc = item.querySelector('.gallery__desc');
        gBusy = true;
        setTimeout(function(){ gBusy = false; }, 700);
        if(hasFlip){
          var state = Flip.getState(gDevices);
          gApply(idx);
          gPlaceMarker(true);
          Flip.from(state, {
            duration:.65, ease:'power3.inOut', absolute:true,
            onEnter:function(els){ gsap.fromTo(els, {opacity:0, y:26*dir, scale:.97}, {opacity:1, y:0, scale:1, duration:.6, ease:'power3.out'}); },
            onLeave:function(els){ gsap.to(els, {opacity:0, y:-26*dir, scale:.97, duration:.6, ease:'power2.in'}); },
            onComplete:function(){ ScrollTrigger.refresh(); }
          });
        }else{
          gApply(idx);
          gPlaceMarker(true);
        }
        if(desc){ gsap.fromTo(desc, {opacity:0, y:10}, {opacity:1, y:0, duration:.45, ease:'power2.out'}); }
        var rect = gDevices[idx].getBoundingClientRect();
        if(rect.bottom < 80 || rect.top > window.innerHeight - 80){
          smoothTo(gDevices[idx], true);
        }
      });
    });

    gPlaceMarker(false);
    window.addEventListener('resize', function(){ gPlaceMarker(false); });
    window.addEventListener('load', function(){ gPlaceMarker(false); });
  }

  /* ---------- 7.5 章节指示胶囊：文字共享元素（同一容器在章节间滑动换字） ---------- */
  var pill = document.getElementById('sectionPill');
  if(pill && 'IntersectionObserver' in window){
    var pillMap = [
      {id:'features', num:'01', txt:'核心能力', dark:false},
      {id:'scenes', num:'02', txt:'使用场景', dark:false},
      {id:'harmonyos', num:'03', txt:'鸿蒙原生', dark:true},
      {id:'download', num:'04', txt:'下载有据', dark:true}
    ];
    var pillNum = document.getElementById('pillNum');
    var pillTxt = document.getElementById('pillTxt');
    var pillBusy = false;
    var pillCurrent = null;

    function pillSlideTo(item){
      if(pillBusy) return;
      pillBusy = true;
      pill.classList.toggle('on-dark', item.dark);
      gsap.to(pillNum, {y:-10, opacity:0, duration:.22, ease:'power2.in', overwrite:true, onComplete:function(){
        pillNum.textContent = item.num;
        gsap.fromTo(pillNum, {y:10, opacity:0}, {y:0, opacity:1, duration:.3, ease:'power3.out', overwrite:true});
      }});
      gsap.to(pillTxt, {yPercent:-130, duration:.28, ease:'power2.in', overwrite:true, onComplete:function(){
        pillTxt.textContent = item.txt;
        gsap.fromTo(pillTxt, {yPercent:130}, {yPercent:0, duration:.36, ease:'power3.out', overwrite:true,
          onComplete:function(){ pillBusy = false; }});
      }});
    }

    var pillIO = new IntersectionObserver(function(entries){
      entries.forEach(function(en){
        if(!en.isIntersecting) return;
        var id = en.target.id;
        if(id === pillCurrent) return;
        pillCurrent = id;
        if(id === 'top'){ pill.classList.remove('is-on'); return; }  /* 回到首屏：胶囊退场 */
        var item = null;
        for(var i = 0; i < pillMap.length; i++){ if(pillMap[i].id === id){ item = pillMap[i]; break; } }
        if(!item) return;
        pill.classList.toggle('on-dark', item.dark);
        if(!pill.classList.contains('is-on')){
          /* 首次出现：内容已就位，胶囊整体浮入 */
          pillTxt.textContent = item.txt;
          pillNum.textContent = item.num;
          pill.classList.add('is-on');
          gsap.fromTo(pill, {y:14}, {y:0, duration:.5, ease:'power3.out', overwrite:true});
        }else{
          pillSlideTo(item);
        }
      });
    }, {rootMargin:'-45% 0px -45% 0px'});
    pillIO.observe(document.getElementById('top'));
    pillMap.forEach(function(m){ var s = document.getElementById(m.id); if(s) pillIO.observe(s); });
  }

  /* ---------- 8. 共享元素转场：截图点击放大（场景 / 核心能力 / 下载）（Flip） ---------- */
  if(hasFlip){
    var zoom = document.getElementById('zoom');
    var stage = document.getElementById('zoomStage');
    var backdrop = document.getElementById('zoomBackdrop');
    var closeBtn = document.getElementById('zoomClose');
    var current = null, ghost = null;

    document.querySelectorAll('.scene .device__screen, .gallery__stage .device__screen, .download .device__screen').forEach(function(screen){
      var card = screen.closest('.scene') || screen.closest('.device');
      card.classList.add('is-zoomable');
      card.setAttribute('role', 'button');
      card.setAttribute('tabindex', '0');
      card.setAttribute('aria-label', '点击查看大图');
      card.addEventListener('click', function(){ openZoom(screen); });
      card.addEventListener('keydown', function(e){
        if(e.key === 'Enter' || e.key === ' '){ e.preventDefault(); openZoom(screen); }
      });
    });

    function openZoom(screen){
      if(current) return;
      current = screen;
      if(lenis){ lenis.stop(); }   /* 放大查看时锁定页面滚动 */
      var state = Flip.getState(screen);
      ghost = screen.cloneNode(true);
      ghost.style.visibility = 'hidden';
      screen.parentNode.appendChild(ghost);
      stage.appendChild(screen);
      zoom.hidden = false;
      gsap.to(backdrop, {opacity:1, duration:.4, ease:'power2.out'});
      Flip.from(state, {duration:.85, ease:'power3.inOut', absolute:true});
      closeBtn.focus();
    }

    function closeZoom(){
      if(!current) return;
      var screen = current;
      var state = Flip.getState(screen);
      ghost.parentNode.insertBefore(screen, ghost);
      ghost.remove();
      ghost = null;
      current = null;
      if(lenis){ lenis.start(); }
      gsap.to(backdrop, {opacity:0, duration:.3, ease:'power2.in', onComplete:function(){ zoom.hidden = true; }});
      Flip.from(state, {duration:.7, ease:'power3.inOut', absolute:true});
    }

    closeBtn.addEventListener('click', closeZoom);
    backdrop.addEventListener('click', closeZoom);
    document.addEventListener('keydown', function(e){ if(e.key === 'Escape') closeZoom(); });
  }

  /* 沉浸光感 / 智感握姿均使用真实录屏循环播放（light-demo.mp4 / grip-demo.mp4），JS 只做视口播放控制 */

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); });
})();
