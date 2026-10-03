/* ============================================================
   有据官网动效 · GSAP + ScrollTrigger
   降级链路：head 内联脚本仅在「非 reduced-motion」时挂 js-motion 类
   → CSS 才隐藏 [data-reveal]；GSAP 缺失或 reduce 时此处移除该类，
   内容零动画但完整可读。
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
  }

  /* ---------- 降级：无 GSAP 或 用户偏好减少动效 ---------- */
  if(!hasGSAP || reduce){
    root.classList.remove('js-motion');
    document.querySelectorAll('.hkit__steps').forEach(function(box){
      box.classList.add('steps-static');
    });
    return;
  }

  gsap.registerPlugin(ScrollTrigger);

  function activate(steps, idx){
    steps.forEach(function(s, i){ s.classList.toggle('is-active', i === idx); });
  }

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

  var mm = gsap.matchMedia();

  /* ---------- 桌面端：pin + scrub 完整叙事 ---------- */
  mm.add('(min-width: 901px)', function(){

    /* 沉浸光感：光斑扫过界面 + 高光带掠过 + 三步文案 */
    var glow = document.querySelector('.immersive-stage .stage-glow');
    var glint = document.querySelector('.immersive-stage .stage-glint');
    var stepsA = document.querySelectorAll('.hkit:not(.hkit--flip) .hkit__step');
    var tl1 = gsap.timeline({
      scrollTrigger:{trigger:'.hkit:not(.hkit--flip)', start:'center 58%', end:'+=1500', scrub:1, pin:true, anticipatePin:1}
    });
    tl1.fromTo(glow, {x:-170, y:-190, scale:.75}, {x:0, y:0, scale:1, duration:1, ease:'none'}, 0)
       .call(activate.bind(null, stepsA, 1), null, 1)
       .to(glow, {x:180, y:170, scale:.85, duration:1, ease:'none'}, 1)
       .fromTo(glint, {xPercent:-130}, {xPercent:130, duration:1.7, ease:'none'}, .25)
       .call(activate.bind(null, stepsA, 2), null, 2);

    /* 智感握姿：高频操作面板随左右握姿迁移 */
    var panel = document.querySelector('.grip-stage .grip-panel');
    var stepsB = document.querySelectorAll('.hkit--flip .hkit__step');
    gsap.set(panel, {xPercent:-50});
    var tl2 = gsap.timeline({
      scrollTrigger:{trigger:'.hkit--flip', start:'center 58%', end:'+=1500', scrub:1, pin:true, anticipatePin:1}
    });
    tl2.to(panel, {x:62, rotation:-2, duration:1, ease:'none'}, 0)
       .call(activate.bind(null, stepsB, 1), null, 1)
       .to(panel, {x:-62, rotation:2, duration:1, ease:'none'}, 1)
       .call(activate.bind(null, stepsB, 2), null, 2)
       .to(panel, {x:0, rotation:0, duration:.8, ease:'none'}, 2);
  });

  /* ---------- 移动端：不 pin，简化为入场动画 ---------- */
  mm.add('(max-width: 900px)', function(){
    var panel = document.querySelector('.grip-stage .grip-panel');
    gsap.set(panel, {xPercent:-50});
    gsap.timeline({scrollTrigger:{trigger:'.grip-stage', start:'top 72%'}})
      .to(panel, {x:40, rotation:-1.5, duration:.8, ease:'power2.inOut'})
      .to(panel, {x:-40, rotation:1.5, duration:.8, ease:'power2.inOut'})
      .to(panel, {x:0, rotation:0, duration:.6, ease:'power2.out'});

    var glow = document.querySelector('.immersive-stage .stage-glow');
    gsap.fromTo(glow,
      {x:-120, y:-140, scale:.7},
      {x:60, y:60, scale:1, duration:2.4, ease:'power1.inOut',
       scrollTrigger:{trigger:'.immersive-stage', start:'top 70%'}});

    var glint = document.querySelector('.immersive-stage .stage-glint');
    gsap.fromTo(glint, {xPercent:-130}, {xPercent:130, duration:1.6, ease:'power1.inOut',
      scrollTrigger:{trigger:'.immersive-stage', start:'top 60%'}});
  });

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); });
})();
