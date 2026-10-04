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
  var darkZones = document.querySelectorAll('.harmony, .download, .footer');
  function syncNav(){
    nav.classList.toggle('is-scrolled', scrolled);
    nav.classList.toggle('nav-invert', inDark);
  }
  function syncDarkZone(){
    var edge = nav.getBoundingClientRect().bottom + 20;
    inDark = false;
    darkZones.forEach(function(zone){
      var r = zone.getBoundingClientRect();
      if(r.top <= edge && r.bottom > edge){ inDark = true; }
    });
    syncNav();
  }
  window.addEventListener('scroll', function(){
    scrolled = window.scrollY > 40;
    syncDarkZone();
  }, {passive:true});
  window.addEventListener('resize', syncDarkZone);
  syncDarkZone();
  if('IntersectionObserver' in window){
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
    lenis.on('scroll', syncDarkZone);
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

  /* ---------- 1.6 滚动速度倾斜：快滚时全站标题侧倾（Lenis velocity → skewX，松手回正） ---------- */
  if(lenis){
    var skewTos = gsap.utils.toArray('.hero__title, .section-head h2').map(function(el){
      return gsap.quickTo(el, 'skewX', {duration:.45, ease:'power3.out'});
    });
    var skewSettle = null;
    lenis.on('scroll', function(e){
      var v = gsap.utils.clamp(-8, 8, (e.velocity || 0) * 0.05);
      skewTos.forEach(function(q){ q(v); });
      if(skewSettle){ clearTimeout(skewSettle); }
      skewSettle = setTimeout(function(){ skewTos.forEach(function(q){ q(0); }); }, 160);
    });
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
    /* hero__sub 改由逐词级联接管（initTitleSplits 内，fonts.ready 后解锁） */
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

  /* ---------- 2.8 逐字动效人格系统（i%5 五路径 × 绑定缓动；标题系统与图库共用） ----------
     ⚠️ 性能铁律：字符只动 transform/opacity（全程合成器驱动，零逐帧栅格化）——
     filter 每帧重栅格化是掉帧主因，严禁回加。 */
  var coarse = window.matchMedia('(pointer:coarse)').matches;
  var K = coarse ? 0.5 : 1;   /* 移动端：位移类维度（x / z / rotationY / skewX）砍半 */

  /* CustomEase silk 三曲线（前段猛后段缓）；插件缺失时回退内置缓动 */
  var E_SILK, E_SOFT, E_BACK;
  if(typeof window.CustomEase !== 'undefined'){
    gsap.registerPlugin(CustomEase);
    CustomEase.create('silk', 'M0,0 C0.16,1 0.3,1 1,1');
    CustomEase.create('silkSoft', 'M0,0 C0.2,0.75 0.4,1 1,1');
    CustomEase.create('silkBack', 'M0,0 C0.34,1.56 0.64,1 1,1');
    E_SILK = 'silk'; E_SOFT = 'silkSoft'; E_BACK = 'silkBack';
  }else{
    E_SILK = 'expo.out'; E_SOFT = 'power3.out'; E_BACK = 'back.out(1.6)';
  }

  /* 每组人格的时间曲线：ease 与路径绑定，动作有性格（不只是参数随机） */
  function motionFor(i){
    var g = i % 5;
    if(g === 0) return { dur:[1.4, 2.2], ease:E_SILK };  /* 翻坠：长滑行 */
    if(g === 1) return { dur:[0.9, 1.5], ease:E_SOFT };  /* 侧甩：快切 */
    if(g === 2) return { dur:[1.6, 2.4], ease:E_SILK };  /* 深推：最深最缓 */
    if(g === 3) return { dur:[1.0, 1.6], ease:E_BACK };  /* 弹升：必过冲 */
    return { dur:[1.2, 1.8], ease:E_BACK };              /* 翻牌：过冲回正 */
  }

  /* from 全函数化（每次触发重新抽签，绝不与写死的 to 混用）：
     i%5 五种入场人格 —— 0 翻坠 / 1 侧甩 / 2 深推 / 3 弹升 / 4 翻牌 */
  function fromVars(){
    return {
      yPercent:function(i){
        var g = i % 5;
        if(g === 0) return gsap.utils.random(120, 260);
        if(g === 3) return gsap.utils.random(60, 140);
        return gsap.utils.random(40, 120);
      },
      rotationX:function(i){
        var g = i % 5;
        if(g === 0) return gsap.utils.random(-85, -60);
        if(g === 2) return gsap.utils.random(-60, -20);
        if(g === 3) return gsap.utils.random(40, 85);
        return gsap.utils.random(-85, -30);
      },
      rotationY:function(i){
        var g = i % 5, s = (i % 2 ? 1 : -1);
        if(g === 1) return s * gsap.utils.random(55, 85) * K;
        if(g === 4) return s * gsap.utils.random(60, 85) * K;
        return gsap.utils.random(-30, 30);
      },
      rotate:function(i){
        var g = i % 5, s = (i % 2 ? 1 : -1);
        if(g === 1) return -s * gsap.utils.random(25, 60);
        return gsap.utils.random(-45, 45);
      },
      x:function(i){
        var g = i % 5, s = (i % 2 ? 1 : -1);
        if(g === 1) return s * gsap.utils.random(140, 260) * K;
        if(g === 4) return s * gsap.utils.random(40, 90) * K;
        return gsap.utils.random(-70, 70);
      },
      skewX:function(i){
        var g = i % 5, s = (i % 2 ? 1 : -1);
        if(g === 1) return s * gsap.utils.random(30, 55) * K;
        return gsap.utils.random(-12, 12);
      },
      z:function(i){
        var g = i % 5;
        if(g === 2) return gsap.utils.random(-900, -450) * K;
        return gsap.utils.random(-260, -40);
      },
      scale:function(i){
        var g = i % 5;
        if(g === 0) return gsap.utils.random(0.5, 0.9);
        if(g === 2) return gsap.utils.random(0.15, 0.45);
        if(g === 3) return gsap.utils.random(1.35, 1.9);
        return gsap.utils.random(0.6, 1.2);
      },
      opacity:0
    };
  }

  /* ---------- 3. 标题逐字揭示（SplitText mask 裁切 + 五路径人格 / 活错峰 / 丝滑收敛 / 性能开关） ---------- */
  /* 拆分统一在 document.fonts.ready 之后执行（避免字体加载后换行/度量错位）；
     SplitText 原生保留嵌套元素（hero 渐变 span）与 <br> 分行。 */
  var hasSplit = typeof window.SplitText !== 'undefined';
  var fontsReady = !hasSplit;
  function revealStaticText(){
    /* 没有字体就绪 API 时跳过 SplitText，保留完整可读的静态文本。 */
    gsap.set('.hero__title', {opacity:1});
    gsap.set('.hero__sub', {opacity:1});
    gsap.utils.toArray('h2[data-reveal], h3[data-reveal]').forEach(function(el){
      el.removeAttribute('data-reveal');
      gsap.set(el, {opacity:1});
    });
  }
  function initTitleSplits(){
    if(!hasSplit) return;

    /* 首屏与章节标题：逐字翻入（i%5 五路径人格 / 活错峰 / 丝滑收敛 / 入场后仍活着 / 性能开关） */
    document.querySelectorAll('.hero__title, h2[data-reveal], h3[data-reveal]').forEach(function(el){
      el.removeAttribute('data-reveal');
      el.classList.add('is-split');
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
          gsap.set(self.chars, fromSet);
          gsap.set(el, {opacity:1, transformStyle:'preserve-3d'});
          var enterTl = null;
          ScrollTrigger.create({
            trigger:el, start:'top 88%',
            onEnter:function(){
              el._entered = true;
              /* 逐字独立补间：duration/ease 由所属路径组绑定（motionFor）、
                 时间位置随机摆放在 1.8s 窗口内（等价 stagger{amount:1.8, from:'random'}）；
                 to 九值全部写死 —— 终点零随机，丝滑收敛；每字落位即释放 will-change。
                 入场期间只保留 transform / opacity，落位后释放合成层占用 */
              if(enterTl){ enterTl.kill(); }
              gsap.set(self.chars, {willChange:'transform, opacity'});
              enterTl = gsap.timeline({delay:0.2});
              self.chars.forEach(function(c, i){
                c.style.animationPlayState = 'paused';
                var m = motionFor(i);
                enterTl.to(c, {
                  yPercent:0, rotationX:0, rotationY:0, rotate:0, x:0, z:0, scale:1, skewX:0,
                  opacity:1,
                  duration:gsap.utils.random(m.dur[0], m.dur[1]),
                  ease:m.ease,
                  overwrite:'auto',
                  onComplete:function(){
                    c.style.willChange = 'auto';
                    c.style.animationPlayState = '';
                  }
                }, gsap.utils.random(0, 1.8));
              });
            },
            onLeaveBack:function(){
              /* 双向循环：滚回时直接落回新一轮随机初态；下一次入场仍固定归零。 */
              el._entered = false;
              if(enterTl){ enterTl.kill(); enterTl = null; }
              gsap.set(self.chars, fromVars());
              gsap.set(self.chars, {willChange:'auto'});
              self.chars.forEach(function(c){ c.style.animationPlayState = ''; });
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

          /* 第七层-点击：冲击波（从点击点最近的字符向外扩散；场景卡内标题除外——那里点击是打开大图） */
          if(!el.closest('.scene')){
            el.addEventListener('click', function(e){
              if(!el._entered) return;
              var idx = 0, best = Infinity;
              self.chars.forEach(function(c, i){
                var r = c.getBoundingClientRect();
                var dx = e.clientX - (r.left + r.width / 2);
                var dy = e.clientY - (r.top + r.height / 2);
                var d = dx * dx + dy * dy;
                if(d < best){ best = d; idx = i; }
              });
              gsap.fromTo(self.chars, {scale:1}, {
                scale:1.26, duration:.2, ease:'power2.out',
                stagger:{each:.04, from:idx}, yoyo:true, repeat:1, overwrite:'auto'
              });
            });
          }
        }
      });
    });

    /* Hero 副标：字级小幅级联（中文无空格分不出词，用小幅度字 cascade 对标宣言区观感） */
    var heroSub = document.querySelector('.hero__sub');
    if(heroSub){
      SplitText.create(heroSub, {
        type:'chars', charsClass:'st-char',
        onSplit:function(self){
          gsap.set(self.chars, {
            yPercent:function(){ return gsap.utils.random(50, 110); },
            opacity:0
          });
          gsap.set(heroSub, {opacity:1});
          gsap.to(self.chars, {yPercent:0, opacity:1, duration:.7, ease:'power3.out', stagger:.012, delay:.35});
        }
      });
    }

    /* 下载 slogan：永动字浪（相位错开的正弦起伏；合成器驱动，滚出视口零成本） */
    var slogan = document.querySelector('.download__slogan');
    if(slogan){
      SplitText.create(slogan, {
        type:'chars', charsClass:'st-char',
        onSplit:function(self){
          gsap.set(self.chars, {y:function(){ return gsap.utils.random(-5, 5); }});
          gsap.to(self.chars, {y:0, duration:.9, ease:'sine.inOut',
            stagger:{each:.07, yoyo:true, repeat:-1}});
        }
      });
    }

    /* CTA 按钮：hover 字符波浪（仅精确指针；与磁吸/flair 分属不同元素不冲突） */
    if(window.matchMedia('(pointer:fine)').matches){
      document.querySelectorAll('.btn--primary .btn__label, .btn--ghost .btn__label').forEach(function(label){
        SplitText.create(label, {
          type:'chars', charsClass:'st-char',
          onSplit:function(self){
            var wave = null;
            label.closest('.btn').addEventListener('mouseenter', function(){
              if(wave){ wave.kill(); }
              wave = gsap.timeline()
                .to(self.chars, {y:-6, duration:.22, ease:'power2.out', stagger:.018})
                .to(self.chars, {y:0, duration:.55, ease:'elastic.out(1,.5)', stagger:.018}, '-=0.28');
            });
          }
        });
      });
    }

    /* 导航品牌与链接：加载时单字级联入场（一次性波次，与 nav 容器 fromTo 衔接） */
    document.querySelectorAll('.nav__brand span, .nav__links a').forEach(function(a, ai){
      SplitText.create(a, {
        type:'chars', charsClass:'st-char',
        onSplit:function(self){
          gsap.set(self.chars, {yPercent:function(){ return gsap.utils.random(50, 100); }, opacity:0});
          gsap.to(self.chars, {yPercent:0, opacity:1, duration:.55, ease:'power3.out',
            stagger:{amount:Math.min(self.chars.length * .02, .3)}, delay:.4 + ai * .08});
        }
      });
    });

    /* 正文与清单小字：单字级联（章节副标 / 场景卡描述 / 鸿蒙特性标签、清单与描述 / 页脚，双向循环）——
       from 函数化每次触发重新抽签，to 写死收敛；小字不挂 mask（避免逐字裁切边缘），只动 yPercent/opacity；
       stagger 用动态 amount（每字 .016s，长文封顶 .6s，短词快切） */
    document.querySelectorAll('.section-head__sub, .scene p, .hkit__tag, .hkit__points li, .hkit__desc, .footer__inner span, .footer__inner a').forEach(function(el){
      SplitText.create(el, {
        type:'chars', charsClass:'st-char',
        onSplit:function(self){
          var amt = Math.min(self.chars.length * .016, .6);
          gsap.set(self.chars, {
            yPercent:function(){ return gsap.utils.random(40, 95); },
            opacity:0
          });
          ScrollTrigger.create({
            trigger:el, start:'top 85%',
            onEnter:function(){
              gsap.to(self.chars, {yPercent:0, opacity:1, duration:.6, ease:'power3.out', stagger:{amount:amt, from:'start'}, overwrite:true});
            },
            onLeaveBack:function(){
              gsap.set(self.chars, {
                yPercent:function(){ return gsap.utils.random(40, 95); },
                opacity:0
              });
            }
          });
        }
      });
    });
  }
  var galleryTextInitFn = null;   /* 图库文字动效初始化（section 7 内挂载，fonts.ready 后调用） */
  if(hasSplit && document.fonts && document.fonts.ready){
    document.fonts.ready.then(function(){
      fontsReady = true;
      initTitleSplits();
      if(galleryTextInitFn){ galleryTextInitFn(); }
    });
  }else{
    /* 没有 Font Loading API 时不拆分，避免字体度量未稳定就建立 mask。 */
    hasSplit = false;
    fontsReady = true;
    /* SplitText 缺失：解除首屏标题门控；h2/h3 保留 data-reveal 走普通淡入 */
    revealStaticText();
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
    gsap.set(chars, {
      opacity:function(){ return gsap.utils.random(.08, .2); },
      y:function(){ return gsap.utils.random(8, 22); },
      rotationX:function(){ return gsap.utils.random(-70, -40); },
      transformPerspective:600
    });
    gsap.to(chars, {opacity:1, y:0, rotationX:0, stagger:.07, ease:'none',
      scrollTrigger:{trigger:el, start:'top 78%', end:'top 28%', scrub:.4}});
  });

  /* ---------- 3.6 眉标/元信息解码（ScrambleText；插件缺失则跳过） ---------- */
  if(hasScramble){
    var decodePool = '有据可依更好的生活出处结构追问理性分享※○△□◇◈/';
    gsap.utils.toArray('.section-head .eyebrow, .download__meta').forEach(function(el){
      var finalText = el.textContent;
      ScrollTrigger.create({
        trigger:el, start:'top 88%', once:true,
        onEnter:function(){
          gsap.to(el, {duration:1.1, scrambleText:{text:finalText, chars:decodePool, speed:.35},
            onComplete:function(){ el.textContent = finalText; }});
        }
      });
    });
    /* 首屏眉标：加载编排落位后直接解码 */
    var heroEyebrow = document.querySelector('.hero__copy .eyebrow');
    if(heroEyebrow){
      var heroEbText = heroEyebrow.textContent;
      gsap.to(heroEyebrow, {duration:1.1, delay:.55, scrambleText:{text:heroEbText, chars:decodePool, speed:.35},
        onComplete:function(){ heroEyebrow.textContent = heroEbText; }});
    }
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
      gsap.to(batch, {autoAlpha:1, y:0, scale:1, duration:.9, ease:'power3.out', stagger:.08, overwrite:'auto'});
    },
    onLeaveBack:function(batch){
      gsap.to(batch, {autoAlpha:0, y:36, scale:.985, duration:.45, ease:'power2.in', stagger:.04, overwrite:'auto'});
    }
  });

  /* ---------- 4.5 鸿蒙特性标签与清单项：已并入 initTitleSplits 的单字级联系统 ---------- */

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
      /* 序号滚动：新激活条目的编号滚入（与章节胶囊同一套语言） */
      var num = gItems[idx].querySelector('.gallery__num');
      if(num){ gsap.fromTo(num, {yPercent:70, opacity:0}, {yPercent:0, opacity:1, duration:.45, ease:'power3.out', overwrite:true}); }
    }

    /* ---------- 7.2 图库文字动效：激活标题「盖戳」级联 + 描述逐行揭示 ---------- */
    var gDescAnim = null;
    function gCascadeTTL(item){
      var chars = item._ttlChars;
      if(!chars || !chars.length) return;
      gsap.set(chars, {
        yPercent:function(i){ return (i % 2 ? -70 : 110); },
        rotationX:function(){ return gsap.utils.random(-85, -50); },
        opacity:0
      });
      gsap.to(chars, {
        yPercent:0, rotationX:0, opacity:1, duration:.55, ease:'power3.out',
        stagger:{amount:.32, from:'random'}, overwrite:'auto',
        onComplete:function(){ gsap.set(chars, {clearProps:'transform,opacity'}); }
      });
    }
    function gRevealDesc(desc){
      if(gDescAnim){ if(gDescAnim.tl){ gDescAnim.tl.kill(); } gDescAnim.split.revert(); gDescAnim = null; }
      if(!hasSplit || !fontsReady || !desc){
        if(desc){ gsap.fromTo(desc, {opacity:0, y:10}, {opacity:1, y:0, duration:.45, ease:'power2.out'}); }
        return;
      }
      var split = SplitText.create(desc, {type:'chars', charsClass:'st-char'});
      gsap.set(split.chars, {yPercent:function(){ return gsap.utils.random(40, 95); }, opacity:0});
      var tl = gsap.to(split.chars, {yPercent:0, opacity:1, duration:.5, ease:'power3.out',
        stagger:{amount:Math.min(split.chars.length * .014, .45), from:'start'}});
      gDescAnim = {split:split, tl:tl};
    }
    /* 拆分四条标题字符（fonts.ready 后经 galleryTextInitFn 调用，供切换时级联重播） */
    galleryTextInitFn = function(){
      gItems.forEach(function(item){
        var ttl = item.querySelector('.gallery__ttl');
        if(ttl && !item._ttlChars){
          SplitText.create(ttl, {
            type:'chars', mask:'chars', charsClass:'st-char',
            onSplit:function(self){ item._ttlChars = self.chars; }
          });
        }
      });
      /* 初始激活卡描述：滚动到图库时播一次单字级联（once；之后的切换级联由 gRevealDesc 接管） */
      var firstDesc = gItems[gActive] && gItems[gActive].querySelector('.gallery__desc');
      if(firstDesc && !gDescAnim){
        ScrollTrigger.create({
          trigger:gItems[gActive], start:'top 80%', once:true,
          onEnter:function(){ gRevealDesc(firstDesc); }
        });
      }
    };

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
        if(desc){ gRevealDesc(desc); }
        gCascadeTTL(item);
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
  if(pill){
    var pillMap = [
      {id:'features', num:'01', txt:'核心能力', dark:false},
      {id:'scenes', num:'02', txt:'使用场景', dark:false},
      {id:'harmonyos', num:'03', txt:'鸿蒙原生', dark:true},
      {id:'download', num:'04', txt:'下载有据', dark:true}
    ];
    var pillNum = document.getElementById('pillNum');
    var pillTxt = document.getElementById('pillTxt');
    var pillBusy = false;
    var pillPending = null;
    var pillCurrent = null;

    function pillSlideTo(item){
      pillPending = item;
      if(pillBusy) return;
      pillBusy = true;
      pillPending = null;
      pill.classList.toggle('on-dark', item.dark);
      gsap.to(pillNum, {y:-10, opacity:0, duration:.22, ease:'power2.in', overwrite:true, onComplete:function(){
        pillNum.textContent = item.num;
        gsap.fromTo(pillNum, {y:10, opacity:0}, {y:0, opacity:1, duration:.3, ease:'power3.out', overwrite:true});
      }});
      gsap.to(pillTxt, {yPercent:-130, duration:.28, ease:'power2.in', overwrite:true, onComplete:function(){
        pillTxt.textContent = item.txt;
        gsap.fromTo(pillTxt, {yPercent:130}, {yPercent:0, duration:.36, ease:'power3.out', overwrite:true,
          onComplete:function(){
            pillBusy = false;
            if(pillPending && pillCurrent === pillPending.id && pill.classList.contains('is-on')){
              var queued = pillPending;
              pillPending = null;
              pillSlideTo(queued);
            }
          }});
      }});
    }

    function syncPillSection(){
      var probe = window.innerHeight * .5;
      var id = 'top';
      var item = null;
      pillMap.forEach(function(m){
        var section = document.getElementById(m.id);
        if(section && section.getBoundingClientRect().top <= probe){
          id = m.id;
          item = m;
        }
      });
      if(id === pillCurrent) return;
      pillCurrent = id;
      if(id === 'top'){
        pillPending = null;
        pillBusy = false;
        gsap.killTweensOf([pill, pillNum, pillTxt]);
        pill.classList.remove('is-on');
        return;
      }
      if(!item) return;
      pill.classList.toggle('on-dark', item.dark);
      if(!pill.classList.contains('is-on')){
        /* 首次出现：内容已就位，胶囊整体浮入 */
        pillPending = null;
        pillTxt.textContent = item.txt;
        pillNum.textContent = item.num;
        pill.classList.add('is-on');
        gsap.fromTo(pill, {y:14}, {y:0, duration:.5, ease:'power3.out', overwrite:true});
      }else{
        pillSlideTo(item);
      }
    }
    window.addEventListener('scroll', syncPillSection, {passive:true});
    window.addEventListener('resize', syncPillSection);
    if(lenis){ lenis.on('scroll', syncPillSection); }
    syncPillSection();
  }

  /* ---------- 8. 共享元素转场：截图点击放大（场景 / 核心能力 / 下载）（Flip） ---------- */
  if(hasFlip){
    var zoom = document.getElementById('zoom');
    var stage = document.getElementById('zoomStage');
    var backdrop = document.getElementById('zoomBackdrop');
    var closeBtn = document.getElementById('zoomClose');
    var current = null, currentTrigger = null, ghost = null;

    document.querySelectorAll('.scene .device__screen, .gallery__stage .device__screen, .download .device__screen').forEach(function(screen){
      var card = screen.closest('.scene') || screen.closest('.device');
      card.classList.add('is-zoomable');
      card.setAttribute('role', 'button');
      card.setAttribute('tabindex', '0');
      card.setAttribute('aria-label', '点击查看大图');
      card.addEventListener('click', function(){ openZoom(screen, card); });
      card.addEventListener('keydown', function(e){
        if(e.key === 'Enter' || e.key === ' '){ e.preventDefault(); openZoom(screen, card); }
      });
    });

    function openZoom(screen, trigger){
      if(current) return;
      current = screen;
      currentTrigger = trigger || null;
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
      var trigger = currentTrigger;
      var state = Flip.getState(screen);
      ghost.parentNode.insertBefore(screen, ghost);
      ghost.remove();
      ghost = null;
      current = null;
      currentTrigger = null;
      if(lenis){ lenis.start(); }
      gsap.to(backdrop, {opacity:0, duration:.3, ease:'power2.in', onComplete:function(){
        zoom.hidden = true;
        if(trigger && trigger.focus){ trigger.focus(); }
      }});
      Flip.from(state, {duration:.7, ease:'power3.inOut', absolute:true});
    }

    closeBtn.addEventListener('click', closeZoom);
    backdrop.addEventListener('click', closeZoom);
    document.addEventListener('keydown', function(e){ if(e.key === 'Escape') closeZoom(); });
  }

  /* 沉浸光感 / 智感握姿均使用真实录屏循环播放（light-demo.mp4 / grip-demo.mp4），JS 只做视口播放控制 */

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); });
})();
