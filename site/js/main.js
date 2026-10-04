/*
 * Youju / Substantiate motion system
 * GSAP drives a small number of deliberate scenes; the page stays complete
 * when GSAP, the network, or reduced-motion preferences make animation unavailable.
 */
(function(){
  'use strict';

  var root = document.documentElement;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hasGSAP = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';
  var finePointer = window.matchMedia('(pointer:fine)').matches;
  var nav = document.getElementById('nav');
  var menuButton = document.querySelector('.nav-toggle');
  var mobileMenu = document.getElementById('mobileMenu');

  function setNavState(){
    if(!nav) return;
    var dark = document.querySelectorAll('.lab, .manifesto, .system, .download, .footer');
    var edge = nav.getBoundingClientRect().bottom + 18;
    var onDark = false;
    dark.forEach(function(section){
      var box = section.getBoundingClientRect();
      if(box.top <= edge && box.bottom > edge) onDark = true;
    });
    nav.classList.toggle('is-scrolled', window.scrollY > 24);
    nav.classList.toggle('nav-invert', onDark);
  }

  function closeMenu(){
    if(!menuButton || !mobileMenu) return;
    menuButton.setAttribute('aria-expanded', 'false');
    mobileMenu.classList.remove('is-open');
    root.classList.remove('menu-open');
  }

  if(menuButton && mobileMenu){
    menuButton.addEventListener('click', function(){
      var open = menuButton.getAttribute('aria-expanded') === 'true';
      menuButton.setAttribute('aria-expanded', String(!open));
      mobileMenu.classList.toggle('is-open', !open);
      root.classList.toggle('menu-open', !open);
    });
    mobileMenu.querySelectorAll('a').forEach(function(link){ link.addEventListener('click', closeMenu); });
  }

  window.addEventListener('scroll', setNavState, {passive:true});
  window.addEventListener('resize', setNavState);
  setNavState();

  /* Videos remain useful in a static/reduced-motion page, but never compete with it. */
  var videos = document.querySelectorAll('.device-video');
  if('IntersectionObserver' in window && videos.length){
    var videoObserver = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if(entry.isIntersecting && !reduce){ entry.target.play().catch(function(){}); }
        else{ entry.target.pause(); }
      });
    }, {threshold:.2});
    videos.forEach(function(video){ videoObserver.observe(video); });
  }

  if(!hasGSAP || reduce){
    root.classList.remove('js-motion');
    videos.forEach(function(video){ video.removeAttribute('autoplay'); video.pause(); });
    return;
  }

  var gsap = window.gsap;
  var ScrollTrigger = window.ScrollTrigger;
  gsap.registerPlugin(ScrollTrigger);

  var lenis = null;
  if(typeof window.Lenis !== 'undefined'){
    lenis = new Lenis({duration:1.15, smoothWheel:true, syncTouch:false});
    lenis.on('scroll', ScrollTrigger.update);
    lenis.on('scroll', setNavState);
    gsap.ticker.add(function(time){ lenis.raf(time * 1000); });
    gsap.ticker.lagSmoothing(0);
    root.classList.add('has-lenis');
    document.querySelectorAll('a[href^="#"]').forEach(function(link){
      link.addEventListener('click', function(event){
        var id = link.getAttribute('href');
        var target = id && id.length > 1 ? document.querySelector(id) : document.body;
        if(!target) return;
        event.preventDefault();
        closeMenu();
        lenis.scrollTo(target, {offset:-78});
      });
    });
  }

  /* ---------- 1. 阅读进度与导航状态 ---------- */
  var progress = document.querySelector('.scroll-progress');
  if(progress){
    gsap.to(progress, {scaleX:1, ease:'none', scrollTrigger:{start:0, end:'max', scrub:.25}});
  }

  /* ---------- 2. 首屏编排 ---------- */
  var intro = gsap.timeline({defaults:{ease:'power3.out'}});
  intro.fromTo('.site-nav', {y:-20, autoAlpha:0}, {y:0, autoAlpha:1, duration:.72}, .05)
    .fromTo('.announcement', {y:-12, autoAlpha:0}, {y:0, autoAlpha:1, duration:.55}, .1)
    .fromTo('.hero__visual', {y:64, scale:.94, autoAlpha:0}, {y:0, scale:1, autoAlpha:1, duration:1.15}, .24)
    .fromTo('.hero__scroll', {y:14, autoAlpha:0}, {y:0, autoAlpha:1, duration:.55}, .85);

  /* ---------- 2.5 Lenis velocity attitude ---------- */
  if(lenis){
    var skewTargets = gsap.utils.toArray('.hero__title, .section-intro h2, .scenes__header h2');
    var skewQuick = skewTargets.map(function(el){ return gsap.quickTo(el, 'skewX', {duration:.38, ease:'power3.out'}); });
    var settle;
    lenis.on('scroll', function(event){
      var velocity = gsap.utils.clamp(-7, 7, (event.velocity || 0) * .055);
      skewQuick.forEach(function(set){ set(velocity); });
      clearTimeout(settle);
      settle = setTimeout(function(){ skewQuick.forEach(function(set){ set(0); }); }, 150);
    });
  }

  /* ---------- 2.8 Hero depth and pointer attitude ---------- */
  gsap.to('.hero__orbit--one', {rotation:360, duration:24, repeat:-1, ease:'none'});
  gsap.to('.hero__orbit--two', {rotation:-360, duration:32, repeat:-1, ease:'none'});
  gsap.to('.signal-ticker__track', {xPercent:-50, duration:28, repeat:-1, ease:'none'});
  gsap.to('.hero__visual', {yPercent:-18, ease:'none', scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.7}});
  gsap.to('.hero__copy', {yPercent:-9, ease:'none', scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.7}});

  if(finePointer){
    var heroVisual = document.querySelector('.hero__visual');
    if(heroVisual){
      var tiltX = gsap.quickTo(heroVisual, 'rotationX', {duration:.65, ease:'power3.out'});
      var tiltY = gsap.quickTo(heroVisual, 'rotationY', {duration:.65, ease:'power3.out'});
      heroVisual.addEventListener('pointermove', function(event){
        var box = heroVisual.getBoundingClientRect();
        tiltX(((event.clientY - box.top) / box.height - .5) * -7);
        tiltY(((event.clientX - box.left) / box.width - .5) * 9);
      });
      heroVisual.addEventListener('pointerleave', function(){ tiltX(0); tiltY(0); });
    }
  }

  /* ---------- 3. 字符系统：字体就绪后拆分，所有字符只使用 transform/opacity ---------- */
  var hasSplit = typeof window.SplitText !== 'undefined';
  var hasCustomEase = typeof window.CustomEase !== 'undefined';
  if(hasCustomEase){
    gsap.registerPlugin(window.CustomEase);
    window.CustomEase.create('youjuSilk', 'M0,0 C0.16,1 0.3,1 1,1');
    window.CustomEase.create('youjuSoft', 'M0,0 C0.2,0.75 0.4,1 1,1');
  }
  var easeSilk = hasCustomEase ? 'youjuSilk' : 'expo.out';
  var easeSoft = hasCustomEase ? 'youjuSoft' : 'power3.out';

  function charFrom(){
    return {
      x:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(35, 150); },
      yPercent:function(i){ return i % 5 === 0 ? gsap.utils.random(110, 230) : gsap.utils.random(35, 120); },
      z:function(i){ return i % 5 === 2 ? gsap.utils.random(-720, -320) : gsap.utils.random(-180, -35); },
      rotationX:function(i){ return i % 5 === 3 ? gsap.utils.random(35, 85) : gsap.utils.random(-85, -25); },
      rotationY:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(25, 82); },
      rotate:function(){ return gsap.utils.random(-34, 34); },
      skewX:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(8, 28); },
      scale:function(i){ return i % 5 === 2 ? gsap.utils.random(.45, .8) : gsap.utils.random(.72, 1.16); },
      opacity:0
    };
  }

  function splitAndAnimate(element, options){
    if(!element || !hasSplit) return;
    var split = new window.SplitText(element, {type:'chars', charsClass:'st-char', ignore:'br'});
    var chars = split.chars || [];
    if(!chars.length) return;
    gsap.set(element, {autoAlpha:1});
    gsap.set(chars, {display:'inline-block', transformOrigin:'50% 100%'});
    if(!(options && options.scroll)) gsap.set(chars, {willChange:'transform, opacity'});
    var vars = options && options.scroll ? {
      opacity:1,
      x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, skewX:0, scale:1,
      stagger:{each:.035, from:'start'}, ease:'none',
      scrollTrigger:{trigger:element, start:'top 78%', end:'top 34%', scrub:.7}
    } : {
      opacity:1,
      x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, skewX:0, scale:1,
      duration:1.25, ease:options && options.manifesto ? easeSoft : easeSilk,
      stagger:{each:options && options.manifesto ? .022 : .028, from:'random'},
      onComplete:function(){ gsap.set(chars, {willChange:'auto'}); }
    };
    gsap.fromTo(chars, charFrom(), vars);
  }

  function runType(){
    if(!hasSplit){
      gsap.set('.hero__title, .manifesto__statement', {autoAlpha:1});
      return;
    }
    splitAndAnimate(document.querySelector('.hero__title'), {});
    splitAndAnimate(document.querySelector('.manifesto__statement'), {manifesto:true, scroll:true});
  }
  if(document.fonts && document.fonts.ready){ document.fonts.ready.then(runType); }
  else{ runType(); }

  /* ---------- 4. Scroll reveals ---------- */
  gsap.utils.toArray('.reveal, [data-reveal]').forEach(function(element){
    gsap.set(element, {willChange:'transform, opacity'});
    gsap.fromTo(element, {y:42, autoAlpha:0}, {
      y:0, autoAlpha:1, duration:.9, ease:'power3.out',
      scrollTrigger:{trigger:element, start:'top 86%', toggleActions:'play none none reverse'},
      onComplete:function(){ gsap.set(element, {willChange:'auto'}); }
    });
  });

  /* ---------- 5. Lab tab switcher ---------- */
  var tabData = [
    {eyebrow:'STRUCTURED PUBLISHING', description:'从视觉骨架开始，自由增删与排序。'},
    {eyebrow:'DAILY NOTE', description:'每天一张卡片，把值得回看的经验留下来。'},
    {eyebrow:'STAR RING', description:'围绕共同兴趣，找到更近的人和更深的讨论。'},
    {eyebrow:'CREATOR SIGNALS', description:'看见内容被认真看过的证据，而不是虚浮的热闹。'}
  ];
  var tabs = gsap.utils.toArray('.lab-tab');
  var screens = gsap.utils.toArray('.lab-screen');
  var labEyebrow = document.getElementById('labEyebrow');
  var labDescription = document.getElementById('labDescription');
  var labIndex = document.getElementById('labIndex');
  var activeFeature = 0;
  function activateFeature(index){
    if(index === activeFeature && screens[index] && screens[index].classList.contains('is-active')) return;
    activeFeature = index;
    tabs.forEach(function(tab, i){
      var active = i === index;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-selected', String(active));
    });
    screens.forEach(function(screen, i){
      var active = i === index;
      screen.classList.toggle('is-active', active);
      screen.setAttribute('aria-hidden', String(!active));
    });
    if(labIndex) labIndex.textContent = String(index + 1).padStart(2, '0');
    if(labEyebrow) labEyebrow.textContent = tabData[index].eyebrow;
    if(labDescription) labDescription.textContent = tabData[index].description;
    var screen = screens[index];
    if(screen){
      gsap.fromTo(screen, {autoAlpha:0, yPercent:10, rotateY:index % 2 ? 7 : -7}, {autoAlpha:1, yPercent:0, rotateY:0, duration:.8, ease:'power3.out', overwrite:true});
    }
  }
  tabs.forEach(function(tab){ tab.addEventListener('click', function(){ activateFeature(Number(tab.dataset.feature) || 0); }); });
  tabs.forEach(function(tab, index){
    tab.setAttribute('aria-controls', 'lab-screen-' + index);
    tab.addEventListener('keydown', function(event){
      if(event.key !== 'ArrowRight' && event.key !== 'ArrowDown' && event.key !== 'ArrowLeft' && event.key !== 'ArrowUp') return;
      event.preventDefault();
      var direction = event.key === 'ArrowRight' || event.key === 'ArrowDown' ? 1 : -1;
      var next = (index + direction + tabs.length) % tabs.length;
      tabs[next].focus();
      activateFeature(next);
    });
  });

  /* ---------- 6. Magnetic actions and quiet hover energy ---------- */
  if(finePointer){
    gsap.utils.toArray('.magnetic').forEach(function(button){
      var x = gsap.quickTo(button, 'x', {duration:.45, ease:'power3.out'});
      var y = gsap.quickTo(button, 'y', {duration:.45, ease:'power3.out'});
      button.addEventListener('pointermove', function(event){
        var box = button.getBoundingClientRect();
        x((event.clientX - (box.left + box.width / 2)) * .18);
        y((event.clientY - (box.top + box.height / 2)) * .18);
      });
      button.addEventListener('pointerleave', function(){ x(0); y(0); });
    });
    gsap.utils.toArray('.principle, .scene-panel, .system__feature').forEach(function(card){
      card.addEventListener('pointermove', function(event){
        var box = card.getBoundingClientRect();
        card.style.setProperty('--mx', ((event.clientX - box.left) / box.width * 100).toFixed(2) + '%');
        card.style.setProperty('--my', ((event.clientY - box.top) / box.height * 100).toFixed(2) + '%');
      });
    });
  }

  /* ---------- 7. GSAP-style horizontal scene story ---------- */
  var scenesSection = document.querySelector('.scenes');
  var track = document.querySelector('.scenes__track');
  var sceneProgress = document.querySelector('.scenes__progress span');
  if(scenesSection && track){
    ScrollTrigger.matchMedia({
      '(min-width: 901px)': function(){
        var tween = gsap.to(track, {x:function(){ return -(track.scrollWidth - window.innerWidth); }, ease:'none', scrollTrigger:{
          trigger:scenesSection, start:'top top', end:function(){ return '+=' + Math.max(1600, track.scrollWidth - window.innerWidth + 520); }, scrub:1, pin:true, anticipatePin:1,
          onUpdate:function(self){ if(sceneProgress) gsap.set(sceneProgress, {scaleX:self.progress}); }
        }});
        return function(){
          if(tween.scrollTrigger) tween.scrollTrigger.kill();
          tween.kill();
          gsap.set(track, {clearProps:'transform'});
        };
      },
      '(max-width: 900px)': function(){
        gsap.set(track, {clearProps:'transform'});
        if(sceneProgress) gsap.set(sceneProgress, {scaleX:1});
      }
    });
  }

  /* ---------- 8. Pointer tilt on product devices ---------- */
  if(finePointer){
    gsap.utils.toArray('.device--lab, .device--scene, .device--download').forEach(function(device){
      var rx = gsap.quickTo(device, 'rotationX', {duration:.65, ease:'power3.out'});
      var ry = gsap.quickTo(device, 'rotationY', {duration:.65, ease:'power3.out'});
      device.addEventListener('pointermove', function(event){
        var box = device.getBoundingClientRect();
        rx(((event.clientY - box.top) / box.height - .5) * -4.5);
        ry(((event.clientX - box.left) / box.width - .5) * 5.5);
      });
      device.addEventListener('pointerleave', function(){ rx(0); ry(0); });
    });
  }

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); setNavState(); });
})();
