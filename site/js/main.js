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
  var heroImg = document.querySelector('.hero__visual .device__screen img');
  if(heroImg){
    /* 截图 scale 1.08 留出裁切余量，滚动时在屏内轻微流动 */
    gsap.fromTo(heroImg, {yPercent:-3.5, scale:1.08}, {yPercent:3.5, scale:1.08, ease:'none',
      scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.6}});
  }
  /* 首屏退场分层（三层深度）：光斑滞后下坠(yPercent +26) < 文案(-16) < 设备(-32) */
  gsap.fromTo('.hero__copy', {yPercent:0}, {yPercent:-16, ease:'none',
    scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:true}});
  gsap.fromTo('.hero__visual', {yPercent:0}, {yPercent:-32, ease:'none',
    scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:true}});

  /* ---------- 3. 标题逐字揭示（mask 内上浮 + 模糊聚焦，双向同步） ---------- */
  /* DOM 感知分割：保留行内元素（如 .grad-text 渐变 span），按 <br> 分行，逐字包 mask */
  function emitChars(text, target, chars){
    Array.from(text).forEach(function(c){
      if(/\s/.test(c)){ target.appendChild(document.createTextNode(' ')); return; }
      var cx = document.createElement('span'); cx.className = 'split-cx';
      var cs = document.createElement('span'); cs.textContent = c;
      cx.appendChild(cs); target.appendChild(cx); chars.push(cs);
    });
  }
  document.querySelectorAll('.hero__title, h2[data-reveal], h3[data-reveal]').forEach(function(el){
    el.removeAttribute('data-reveal');
    var chars = [];
    var lines = [];
    var line = document.createElement('span'); line.className = 'split-ln';
    function flush(){
      if(line.childNodes.length){ lines.push(line); }
      line = document.createElement('span'); line.className = 'split-ln';
    }
    Array.prototype.slice.call(el.childNodes).forEach(function(n){
      if(n.nodeType === 3){ emitChars(n.textContent, line, chars); }
      else if(n.nodeType === 1 && n.tagName === 'BR'){ flush(); }
      else if(n.nodeType === 1){
        var clone = n.cloneNode(false);
        line.appendChild(clone);
        Array.prototype.slice.call(n.childNodes).forEach(function(nn){
          if(nn.nodeType === 3){ emitChars(nn.textContent, clone, chars); }
          else if(nn.nodeType === 1 && nn.tagName === 'BR'){ clone.appendChild(document.createElement('br')); }
          else{ emitChars(nn.textContent, clone, chars); }
        });
      }
    });
    flush();
    el.innerHTML = '';
    lines.forEach(function(l){ el.appendChild(l); });
    gsap.set(chars, {yPercent:118, opacity:0, filter:'blur(8px)'});
    ScrollTrigger.create({
      trigger:el, start:'top 88%',
      onEnter:function(){
        gsap.to(chars, {yPercent:0, opacity:1, filter:'blur(0px)', duration:.9, ease:'power3.out', stagger:.02, delay:.12, overwrite:true});
      },
      onLeaveBack:function(){
        gsap.to(chars, {yPercent:118, opacity:0, filter:'blur(8px)', duration:.4, ease:'power2.in', stagger:.01, overwrite:true});
      }
    });
  });

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

  /* ---------- 4. 入场 reveal（双向循环，带纵向缩放） ---------- */
  var reveals = document.querySelectorAll('[data-reveal]');
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
