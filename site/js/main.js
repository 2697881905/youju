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

  /* ---------- 入场 reveal ---------- */
  var reveals = document.querySelectorAll('[data-reveal]');
  gsap.set(reveals, {y:36});
  ScrollTrigger.batch(reveals, {
    start:'top 88%',
    once:true,
    onEnter:function(batch){
      gsap.to(batch, {autoAlpha:1, y:0, duration:.9, ease:'power3.out', stagger:.08, overwrite:true});
    }
  });

  /* 沉浸光感 / 智感握姿均使用真实录屏循环播放（light-demo.mp4 / grip-demo.mp4），JS 只做视口播放控制 */

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); });
})();
