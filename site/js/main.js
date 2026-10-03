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
  }

  /* ---------- 降级：无 GSAP 或用户偏好减少动效 ---------- */
  if(!hasGSAP || reduce){
    root.classList.remove('js-motion');
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

  /* ---------- 沉浸光感：光点沿界面循环游走（光随指动） ---------- */
  var glow = document.querySelector('.glow-cursor');
  if(glow){
    gsap.timeline({repeat:-1, defaults:{ease:'sine.inOut', duration:1.7}})
      .fromTo(glow, {xPercent:-42, yPercent:-72}, {xPercent:32, yPercent:-18})
      .to(glow, {xPercent:56, yPercent:52})
      .to(glow, {xPercent:-28, yPercent:76, duration:2})
      .to(glow, {xPercent:-42, yPercent:-72});
  }

  /* ---------- 智感握姿：发送按钮随左右手循环迁移 ---------- */
  var send = document.querySelector('.grip-send');
  var hand = document.querySelector('.grip-hand');
  var state = document.getElementById('handState');
  if(send && hand){
    // 按钮从右侧 4% 移到左侧 4% 所需的 x 位移（随屏幕宽度自适应）
    function gripShift(){
      var screen = send.closest('.device__screen');
      return -(screen.clientWidth - send.offsetWidth - screen.clientWidth * 0.08);
    }
    gsap.timeline({repeat:-1, repeatRefresh:true, repeatDelay:.8, defaults:{ease:'power3.inOut'}})
      .to([send, hand], {x:function(){return gripShift();}, duration:1.1})
      .call(function(){ if(state) state.textContent = '左手'; }, null, .55)
      .to(send, {scale:.93, duration:.16, yoyo:true, repeat:1, ease:'power2.out'}, '+=.3')
      .to(hand, {y:4, duration:.16, yoyo:true, repeat:1, ease:'power2.out'}, '<')
      .to({}, {duration:.8})
      .to([send, hand], {x:0, duration:1.1})
      .call(function(){ if(state) state.textContent = '右手'; }, null, '-=.55');
  }

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); });
})();
