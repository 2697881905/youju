/* ============================================================
   有据官网动效 · GSAP + ScrollTrigger
   - 入场 reveal：滚动触发（ScrollTrigger.batch）
   - 沉浸光感 / 智感握姿：自动循环动画（不依赖滚动方向，桌面移动一致）
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

  /* ---------- 1. 标题逐字揭示（mask 内上浮，与 reveal 双向同步） ---------- */
  document.querySelectorAll('h1[data-reveal], h2[data-reveal], h3[data-reveal]').forEach(function(el){
    el.removeAttribute('data-reveal');
    var lines = el.innerHTML.split(/<br\s*\/?>/i);
    el.innerHTML = lines.map(function(part){
      var chars = Array.from(part).map(function(c){
        return c === ' ' ? ' ' : '<span class="split-cx"><span>' + c + '</span></span>';
      }).join('');
      return '<span class="split-ln">' + chars + '</span>';
    }).join('');
    var chars = el.querySelectorAll('.split-cx>span');
    gsap.set(chars, {yPercent:118, opacity:0});
    ScrollTrigger.create({
      trigger:el, start:'top 88%',
      onEnter:function(){
        gsap.to(chars, {yPercent:0, opacity:1, duration:.85, ease:'power3.out', stagger:.022, overwrite:true});
      },
      onLeaveBack:function(){
        gsap.to(chars, {yPercent:118, opacity:0, duration:.4, ease:'power2.in', stagger:.012, overwrite:true});
      }
    });
  });

  /* ---------- 2. 入场 reveal（双向循环） ---------- */
  var reveals = document.querySelectorAll('[data-reveal]');
  gsap.set(reveals, {y:36});
  ScrollTrigger.batch(reveals, {
    start:'top 88%',
    onEnter:function(batch){
      gsap.to(batch, {autoAlpha:1, y:0, duration:.9, ease:'power3.out', stagger:.08, overwrite:true});
    },
    onLeaveBack:function(batch){
      gsap.to(batch, {autoAlpha:0, y:36, duration:.45, ease:'power2.in', stagger:.04, overwrite:true});
    }
  });

  /* ---------- 3. 截图滚动视差 + Hero 设备呼吸浮动 ---------- */
  gsap.utils.toArray('.feature .device, .scene .device').forEach(function(d){
    gsap.fromTo(d, {y:38}, {
      y:-38, ease:'none',
      scrollTrigger:{trigger:d, start:'top bottom', end:'bottom top', scrub:.5}
    });
  });
  gsap.to('.hero__visual .device', {y:-11, duration:3.2, ease:'sine.inOut', repeat:-1, yoyo:true});

  /* ---------- 4. 共享元素转场：场景截图点击放大（Flip） ---------- */
  if(hasFlip){
    var zoom = document.getElementById('zoom');
    var stage = document.getElementById('zoomStage');
    var backdrop = document.getElementById('zoomBackdrop');
    var closeBtn = document.getElementById('zoomClose');
    var current = null, ghost = null;

    document.querySelectorAll('.scene .device__screen').forEach(function(screen){
      var card = screen.closest('.scene');
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
