/* Youju motion system: a restrained Apple-like layout with GSAP's continuous movement. */
(function(){
  'use strict';

  var root = document.documentElement;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var finePointer = window.matchMedia('(pointer:fine)').matches;
  var hasGSAP = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';
  var nav = document.getElementById('nav');
  var menuButton = document.querySelector('.nav-toggle');
  var mobileMenu = document.getElementById('mobileMenu');

  function syncNav(){
    if(!nav) return;
    var darkSections = document.querySelectorAll('.features, .harmony, .download, .footer');
    var edge = nav.getBoundingClientRect().bottom + 12;
    var dark = false;
    darkSections.forEach(function(section){
      var box = section.getBoundingClientRect();
      if(box.top <= edge && box.bottom > edge) dark = true;
    });
    nav.classList.toggle('is-scrolled', window.scrollY > 18);
    nav.classList.toggle('nav-invert', dark);
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
  window.addEventListener('scroll', syncNav, {passive:true});
  window.addEventListener('resize', syncNav);
  syncNav();

  var videos = document.querySelectorAll('.device-video');
  if('IntersectionObserver' in window && videos.length){
    var videoObserver = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if(entry.isIntersecting && !reduce) entry.target.play().catch(function(){});
        else entry.target.pause();
      });
    }, {threshold:.18});
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
    lenis = new Lenis({duration:1.12, smoothWheel:true, syncTouch:false});
    lenis.on('scroll', ScrollTrigger.update);
    lenis.on('scroll', syncNav);
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
        lenis.scrollTo(target, {offset:-76});
      });
    });

    var skewTargets = gsap.utils.toArray('.hero__title, .section-heading h2, .scenes__intro h2, .download h2');
    var skewQuick = skewTargets.map(function(element){ return gsap.quickTo(element, 'skewX', {duration:.42, ease:'power3.out'}); });
    var settleSkew;
    lenis.on('scroll', function(event){
      var velocity = gsap.utils.clamp(-4, 4, (event.velocity || 0) * .035);
      skewQuick.forEach(function(set){ set(velocity); });
      clearTimeout(settleSkew);
      settleSkew = setTimeout(function(){ skewQuick.forEach(function(set){ set(0); }); }, 140);
    });
  }

  /* ---------- Navigation progress ---------- */
  var progress = document.querySelector('.scroll-progress');
  if(progress) gsap.to(progress, {scaleX:1, ease:'none', scrollTrigger:{start:0, end:'max', scrub:.25}});

  /* ---------- Hero entrance and atmosphere ---------- */
  gsap.timeline({defaults:{ease:'power3.out'}})
    .fromTo('.site-nav', {y:-18, autoAlpha:0}, {y:0, autoAlpha:1, duration:.65}, .05)
    .fromTo('.hero__copy .eyebrow', {y:20, autoAlpha:0}, {y:0, autoAlpha:1, duration:.65}, .14)
    .fromTo('.hero__lead, .hero__actions', {y:26, autoAlpha:0}, {y:0, autoAlpha:1, duration:.8, stagger:.1}, .42)
    .fromTo('.hero__stage', {y:50, autoAlpha:0, scale:.94}, {y:0, autoAlpha:1, scale:1, duration:1.1}, .24)
    .fromTo('.hero__rail', {y:12, autoAlpha:0}, {y:0, autoAlpha:1, duration:.55}, .9);
  gsap.to('.hero__ring--one', {rotation:360, duration:28, repeat:-1, ease:'none'});
  gsap.to('.hero__ring--two', {rotation:-360, duration:21, repeat:-1, ease:'none'});
  gsap.to('.hero__beam', {x:100, duration:8, repeat:-1, yoyo:true, ease:'sine.inOut'});
  gsap.to('.download__orbit', {rotation:372, duration:26, repeat:-1, ease:'none'});
  gsap.to('.hero__stage', {yPercent:-16, ease:'none', scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.8}});
  gsap.to('.hero__copy', {yPercent:-8, ease:'none', scrollTrigger:{trigger:'.hero', start:'top top', end:'bottom top', scrub:.8}});

  if(finePointer){
    var heroStage = document.querySelector('.hero__stage');
    if(heroStage){
      var stageX = gsap.quickTo(heroStage, 'rotationX', {duration:.7, ease:'power3.out'});
      var stageY = gsap.quickTo(heroStage, 'rotationY', {duration:.7, ease:'power3.out'});
      heroStage.addEventListener('pointermove', function(event){
        var box = heroStage.getBoundingClientRect();
        stageX(((event.clientY - box.top) / box.height - .5) * -5);
        stageY(((event.clientX - box.left) / box.width - .5) * 7);
      });
      heroStage.addEventListener('pointerleave', function(){ stageX(0); stageY(0); });
    }
  }

  /* ---------- Typography: deterministic, physical, never beyond safe 3D angles ---------- */
  var hasSplit = typeof window.SplitText !== 'undefined';
  var hasCustomEase = typeof window.CustomEase !== 'undefined';
  if(hasCustomEase){
    gsap.registerPlugin(window.CustomEase);
    window.CustomEase.create('youjuSilk', 'M0,0 C0.16,1 0.3,1 1,1');
    window.CustomEase.create('youjuLift', 'M0,0 C0.24,0.9 0.38,1 1,1');
  }
  var easeSilk = hasCustomEase ? 'youjuSilk' : 'expo.out';
  var easeLift = hasCustomEase ? 'youjuLift' : 'power3.out';

  function charFrom(){
    return {
      x:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(45, 115); },
      yPercent:function(i){ return i % 4 === 0 ? gsap.utils.random(90, 165) : gsap.utils.random(32, 88); },
      z:function(i){ return i % 4 === 2 ? gsap.utils.random(-420, -180) : gsap.utils.random(-120, -30); },
      rotationX:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(8, 22); },
      rotationY:function(i){ return (i % 2 ? 1 : -1) * gsap.utils.random(8, 20); },
      rotate:function(){ return gsap.utils.random(-12, 12); },
      scale:function(i){ return i % 4 === 2 ? gsap.utils.random(.7, .9) : gsap.utils.random(.84, 1.08); },
      opacity:0
    };
  }

  function splitIn(element, options){
    if(!element || !hasSplit) return;
    var split = new window.SplitText(element, {type:'chars', charsClass:'st-char', ignore:'br'});
    var chars = split.chars || [];
    if(!chars.length) return;
    gsap.set(element, {autoAlpha:1});
    gsap.set(chars, {display:'inline-block', transformOrigin:'50% 100%'});
    var scroll = options && options.scroll;
    if(!scroll) gsap.set(chars, {willChange:'transform, opacity'});
    gsap.fromTo(chars, charFrom(), scroll ? {
      x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, scale:1, opacity:1,
      stagger:{each:.035, from:'start'}, ease:'none',
      scrollTrigger:{trigger:element, start:'top 80%', end:'top 35%', scrub:.7}
    } : {
      x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, scale:1, opacity:1,
      duration:1.15, ease:options && options.statement ? easeLift : easeSilk,
      stagger:{each:options && options.statement ? .024 : .03, from:'random'},
      onComplete:function(){ gsap.set(chars, {willChange:'auto'}); }
    });
  }
  function initType(){
    if(!hasSplit){ gsap.set('.hero__title, .statement__text', {autoAlpha:1}); return; }
    splitIn(document.querySelector('.hero__title'), {});
    splitIn(document.querySelector('.statement__text'), {statement:true, scroll:true});
  }
  if(document.fonts && document.fonts.ready){
    document.fonts.ready.then(function(){ initType(); ScrollTrigger.refresh(); });
  } else initType();

  /* ---------- Reveals ---------- */
  gsap.utils.toArray('.reveal, [data-reveal]').forEach(function(element){
    gsap.set(element, {willChange:'transform, opacity'});
    gsap.fromTo(element, {y:38, autoAlpha:0}, {y:0, autoAlpha:1, duration:.85, ease:easeLift, scrollTrigger:{trigger:element, start:'top 86%', toggleActions:'play none none reverse'}, onComplete:function(){ gsap.set(element, {willChange:'auto'}); }});
  });

  /* ---------- Product tabs ---------- */
  var featureTabs = gsap.utils.toArray('.feature-tab');
  var featureScreens = gsap.utils.toArray('.feature-screen');
  var featureDescriptions = ['从视觉骨架开始，自由增删与排序。','每天一张卡片，把值得回看的经验留下来。','围绕共同兴趣，找到更近的人和更深的讨论。'];
  var featureNumber = document.getElementById('featureNumber');
  var featureDescription = document.getElementById('featureDescription');
  var featureCurrent = 0;
  function activateFeature(index){
    if(index === featureCurrent && featureScreens[index].classList.contains('is-active')) return;
    featureCurrent = index;
    featureTabs.forEach(function(tab, i){ var active = i === index; tab.classList.toggle('is-active', active); tab.setAttribute('aria-selected', String(active)); tab.setAttribute('aria-controls', 'feature-screen-' + i); });
    featureScreens.forEach(function(screen, i){ var active = i === index; screen.classList.toggle('is-active', active); screen.setAttribute('aria-hidden', String(!active)); });
    if(featureNumber) featureNumber.textContent = String(index + 1).padStart(2, '0');
    if(featureDescription) featureDescription.textContent = featureDescriptions[index];
    gsap.fromTo(featureScreens[index], {autoAlpha:0, yPercent:12, rotationY:index % 2 ? 8 : -8}, {autoAlpha:1, yPercent:0, rotationY:0, duration:.85, ease:easeLift, overwrite:true});
  }
  featureTabs.forEach(function(tab, index){
    tab.setAttribute('aria-controls', 'feature-screen-' + index);
    tab.addEventListener('click', function(){ activateFeature(index); });
    tab.addEventListener('keydown', function(event){
      if(event.key !== 'ArrowRight' && event.key !== 'ArrowDown' && event.key !== 'ArrowLeft' && event.key !== 'ArrowUp') return;
      event.preventDefault();
      var direction = event.key === 'ArrowRight' || event.key === 'ArrowDown' ? 1 : -1;
      var next = (index + direction + featureTabs.length) % featureTabs.length;
      featureTabs[next].focus();
      activateFeature(next);
    });
  });

  /* ---------- Magnetic buttons and pointer spotlight ---------- */
  if(finePointer){
    gsap.utils.toArray('.magnetic').forEach(function(button){
      var x = gsap.quickTo(button, 'x', {duration:.45, ease:easeLift});
      var y = gsap.quickTo(button, 'y', {duration:.45, ease:easeLift});
      button.addEventListener('pointermove', function(event){
        var box = button.getBoundingClientRect();
        x((event.clientX - (box.left + box.width / 2)) * .16);
        y((event.clientY - (box.top + box.height / 2)) * .16);
      });
      button.addEventListener('pointerleave', function(){ x(0); y(0); });
    });
    gsap.utils.toArray('.principle, .scene-panel').forEach(function(element){
      element.addEventListener('pointermove', function(event){
        var box = element.getBoundingClientRect();
        element.style.setProperty('--mx', ((event.clientX - box.left) / box.width * 100).toFixed(1) + '%');
        element.style.setProperty('--my', ((event.clientY - box.top) / box.height * 100).toFixed(1) + '%');
      });
    });
  }

  /* ---------- Continuous horizontal story ---------- */
  var scenes = document.querySelector('.scenes');
  var track = document.querySelector('.scenes__track');
  var sceneProgress = document.querySelector('.scenes__progress span');
  if(scenes && track){
    ScrollTrigger.matchMedia({
      '(min-width: 901px)': function(){
        var horizontal = gsap.to(track, {x:function(){ return -(track.scrollWidth - window.innerWidth); }, ease:'none', scrollTrigger:{trigger:scenes, start:'top top', end:function(){ return '+=' + Math.max(1700, track.scrollWidth - window.innerWidth + 260); }, scrub:1, pin:true, anticipatePin:1, onUpdate:function(self){ if(sceneProgress) gsap.set(sceneProgress, {scaleX:self.progress}); }}});
        gsap.utils.toArray('.scene-panel').forEach(function(panel){
          gsap.fromTo(panel.querySelector('.scene-panel__copy'), {x:90, autoAlpha:.2}, {x:0, autoAlpha:1, ease:'none', scrollTrigger:{trigger:panel, containerAnimation:horizontal, start:'left 78%', end:'left 38%', scrub:.7}});
          gsap.fromTo(panel.querySelector('.device'), {scale:.78, rotation:panel.classList.contains('scene-panel--white') ? -8 : 8, autoAlpha:.55}, {scale:1, rotation:0, autoAlpha:1, ease:'none', scrollTrigger:{trigger:panel, containerAnimation:horizontal, start:'left 82%', end:'left 35%', scrub:.8}});
        });
        return function(){ if(horizontal.scrollTrigger) horizontal.scrollTrigger.kill(); horizontal.kill(); gsap.set(track, {clearProps:'transform'}); };
      },
      '(max-width: 900px)': function(){ gsap.set(track, {clearProps:'transform'}); if(sceneProgress) gsap.set(sceneProgress, {scaleX:1}); }
    });
  }

  /* ---------- Product devices respond to the pointer ---------- */
  if(finePointer){
    gsap.utils.toArray('.device--feature, .device--scene, .device--download').forEach(function(device){
      var x = gsap.quickTo(device, 'rotationX', {duration:.65, ease:easeLift});
      var y = gsap.quickTo(device, 'rotationY', {duration:.65, ease:easeLift});
      device.addEventListener('pointermove', function(event){
        var box = device.getBoundingClientRect();
        x(((event.clientY - box.top) / box.height - .5) * -4);
        y(((event.clientX - box.left) / box.width - .5) * 5);
      });
      device.addEventListener('pointerleave', function(){ x(0); y(0); });
    });
  }

  gsap.utils.toArray('.harmony__feature').forEach(function(feature){
    gsap.fromTo(feature.querySelector('.harmony__copy'), {x:feature.classList.contains('harmony__feature--second') ? 50 : -50, autoAlpha:.35}, {x:0, autoAlpha:1, duration:1, ease:easeLift, scrollTrigger:{trigger:feature, start:'top 78%', end:'top 35%', scrub:.7}});
    gsap.fromTo(feature.querySelector('.video-frame'), {y:70, scale:.9, autoAlpha:.35}, {y:0, scale:1, autoAlpha:1, duration:1, ease:easeLift, scrollTrigger:{trigger:feature, start:'top 82%', end:'top 32%', scrub:.8}});
  });

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); syncNav(); });
})();
