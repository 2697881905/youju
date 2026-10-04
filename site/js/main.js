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
    if(typeof lenis !== 'undefined' && lenis) lenis.start();
  }

  if(menuButton && mobileMenu){
    menuButton.addEventListener('click', function(){
      var open = menuButton.getAttribute('aria-expanded') === 'true';
      menuButton.setAttribute('aria-expanded', String(!open));
      mobileMenu.classList.toggle('is-open', !open);
      root.classList.toggle('menu-open', !open);
      if(typeof lenis !== 'undefined' && lenis){ if(open) lenis.start(); else lenis.stop(); }
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

  /* ---------- Typography: five personalities, scroll light, pointer lift ---------- */
  var hasSplit = typeof window.SplitText !== 'undefined';
  var hasCustomEase = typeof window.CustomEase !== 'undefined';
  var hasScramble = typeof window.ScrambleTextPlugin !== 'undefined';
  var coarse = window.matchMedia('(pointer:coarse)').matches;
  var K = coarse ? .5 : 1;
  if(hasCustomEase){
    gsap.registerPlugin(window.CustomEase);
    window.CustomEase.create('youjuSilk', 'M0,0 C0.16,1 0.3,1 1,1');
    window.CustomEase.create('youjuSoft', 'M0,0 C0.2,0.75 0.4,1 1,1');
    window.CustomEase.create('youjuBack', 'M0,0 C0.34,1.56 0.64,1 1,1');
  }
  if(hasSplit) gsap.registerPlugin(window.SplitText);
  if(hasScramble) gsap.registerPlugin(window.ScrambleTextPlugin);
  var easeSilk = hasCustomEase ? 'youjuSilk' : 'expo.out';
  var easeSoft = hasCustomEase ? 'youjuSoft' : 'power3.out';
  var easeBack = hasCustomEase ? 'youjuBack' : 'back.out(1.5)';
  var easeLift = easeSoft;

  function motionFor(index){
    var group = index % 5;
    if(group === 0) return {duration:[1.25, 1.95], ease:easeSilk};
    if(group === 1) return {duration:[.78, 1.28], ease:easeSoft};
    if(group === 2) return {duration:[1.45, 2.2], ease:easeSilk};
    if(group === 3) return {duration:[.92, 1.45], ease:easeBack};
    return {duration:[1.05, 1.7], ease:easeBack};
  }

  /* Every initial value is a function; every resting value below is explicit zero/one. */
  function charFrom(){
    return {
      x:function(i){ var g=i%5, s=i%2 ? 1 : -1; return (g===1 ? s*gsap.utils.random(120,240) : gsap.utils.random(-70,70)) * K; },
      yPercent:function(i){ var g=i%5; return g===0 ? gsap.utils.random(120,240) : g===3 ? gsap.utils.random(60,140) : gsap.utils.random(34,118); },
      z:function(i){ return (i%5===2 ? gsap.utils.random(-760,-360) : gsap.utils.random(-220,-35)) * K; },
      rotationX:function(i){ var g=i%5; if(g===0) return gsap.utils.random(-84,-58); if(g===3) return gsap.utils.random(42,84); return gsap.utils.random(-76,-22); },
      rotationY:function(i){ var g=i%5, s=i%2 ? 1 : -1; return g===1 || g===4 ? s*gsap.utils.random(54,84)*K : gsap.utils.random(-26,26); },
      rotate:function(i){ return i%5===1 ? gsap.utils.random(-52,52) : gsap.utils.random(-28,28); },
      skewX:function(i){ return i%5===1 ? (i%2 ? 1 : -1)*gsap.utils.random(24,48)*K : gsap.utils.random(-10,10); },
      scale:function(i){ var g=i%5; if(g===0) return gsap.utils.random(.55,.9); if(g===2) return gsap.utils.random(.2,.55); if(g===3) return gsap.utils.random(1.2,1.75); return gsap.utils.random(.68,1.16); },
      opacity:0
    };
  }

  function animateChars(chars, options){
    var timeline = gsap.timeline({delay:options && options.delay || 0});
    gsap.set(chars, {willChange:'transform, opacity'});
    chars.forEach(function(char, index){
      var motion = motionFor(index);
      timeline.to(char, {
        x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, skewX:0, scale:1, opacity:1,
        duration:gsap.utils.random(motion.duration[0], motion.duration[1]), ease:motion.ease, overwrite:'auto',
        onComplete:function(){ char.style.willChange='auto'; }
      }, options && options.statement ? index*.024 : gsap.utils.random(0, 1.65));
    });
    return timeline;
  }

  function pointerAndClick(el, chars){
    if(!finePointer) return;
    var rects = null;
    el.addEventListener('mouseenter', function(){ rects=chars.map(function(char){ return char.getBoundingClientRect(); }); });
    el.addEventListener('mousemove', function(event){
      if(!rects) return;
      chars.forEach(function(char, index){
        var rect=rects[index];
        var influence=Math.max(0, 1 - Math.abs(event.clientX-(rect.left+rect.width/2))/(rect.width*3+1));
        gsap.to(char, {y:-12*influence, duration:.3, ease:'power2.out', overwrite:'auto'});
      });
    });
    el.addEventListener('mouseleave', function(){ rects=null; gsap.to(chars, {y:0, duration:.45, ease:'power3.out', overwrite:'auto'}); });
    el.addEventListener('click', function(event){
      var nearest=0, distance=Infinity;
      chars.forEach(function(char,index){ var rect=char.getBoundingClientRect(); var dx=event.clientX-(rect.left+rect.width/2); var dy=event.clientY-(rect.top+rect.height/2); var value=dx*dx+dy*dy; if(value<distance){ distance=value; nearest=index; } });
      gsap.fromTo(chars, {scale:1}, {scale:1.2, duration:.18, ease:'power2.out', stagger:{each:.035, from:nearest}, yoyo:true, repeat:1, overwrite:'auto'});
    });
  }

  function splitHeading(element, options){
    if(!element || !hasSplit || element.dataset.motionSplit) return;
    element.dataset.motionSplit='true';
    var split = new window.SplitText(element, {type:'chars', charsClass:'st-char', ignore:'br'});
    var chars = split.chars || [];
    if(!chars.length) return;
    gsap.set(element, {autoAlpha:1, transformStyle:'preserve-3d'});
    if(options && options.statement){
      gsap.set(chars, {display:'inline-block', transformOrigin:'50% 100%', transformPerspective:800, force3D:true, backfaceVisibility:'hidden', x:0, z:0, rotationY:0, rotate:0, skewX:0, scale:1, opacity:function(){ return gsap.utils.random(.1,.22); }, y:function(){ return gsap.utils.random(10,24); }, rotationX:function(){ return gsap.utils.random(-72,-42); }});
      gsap.to(chars, {x:0, z:0, rotationY:0, rotate:0, skewX:0, scale:1, opacity:1, y:0, rotationX:0, stagger:.055, ease:'none', scrollTrigger:{trigger:element, start:'top 82%', end:'top 30%', scrub:.45}});
    }else if(options && options.immediate){
      gsap.set(chars, Object.assign(charFrom(), {display:'inline-block', transformOrigin:'50% 100%', transformPerspective:800, force3D:true, backfaceVisibility:'hidden'}));
      animateChars(chars, {delay:options.delay || .16});
    }else{
      gsap.set(chars, Object.assign(charFrom(), {display:'inline-block', transformOrigin:'50% 100%', transformPerspective:800, force3D:true, backfaceVisibility:'hidden'}));
      var enter;
      ScrollTrigger.create({trigger:element, start:'top 86%', onEnter:function(){ if(enter) enter.kill(); enter=animateChars(chars, {}); }});
    }
    if(options && options.interactive !== false) pointerAndClick(element, chars);
  }

  function cascadeText(element, options){
    if(!element || !hasSplit || element.dataset.motionSplit) return;
    element.dataset.motionSplit='true';
    var split = new window.SplitText(element, {type:'chars', charsClass:'st-char', ignore:'br'});
    var chars = split.chars || [];
    if(!chars.length) return;
    var amount=Math.min(chars.length*.018,.7);
    gsap.set(chars, {display:'inline-block', yPercent:function(){ return gsap.utils.random(40,100); }, opacity:0});
    var enter=function(){ gsap.set(chars, {willChange:'transform, opacity'}); gsap.to(chars, {yPercent:0, opacity:1, duration:.62, ease:easeSoft, delay:options && options.delay || 0, stagger:{amount:amount, from:options && options.from || 'start'}, overwrite:'auto', onComplete:function(){ gsap.set(chars,{willChange:'auto'}); }}); };
    ScrollTrigger.create({trigger:element, start:'top 88%', onEnter:enter});
  }

  function initType(){
    if(!hasSplit){ gsap.set('.hero__title, .statement__text', {autoAlpha:1}); return; }
    splitHeading(document.querySelector('.hero__title'), {immediate:true, delay:.2});
    splitHeading(document.querySelector('.statement__text'), {statement:true, interactive:true});
    gsap.utils.toArray('.section-heading h2, .scenes__intro h2, .harmony__copy h3, .download h2, .principle h3, .scene-panel__copy h3').forEach(function(element){ splitHeading(element, {interactive:true}); });
    gsap.utils.toArray('.hero__lead, .section-heading > p:last-child, .principle p, .principle__number, .feature-tab strong, .feature-workbench__hint, .feature-workbench__copy > span, .feature-workbench__copy p, .scene-panel__copy > span, .scene-panel__copy > b, .scene-panel__copy p, .harmony__copy > span, .harmony__copy p, .hero__stage-note span, .hero__stage-note strong, .hero__rail span, .download__copy > p:last-of-type, .footer__top > span, .footer__bottom > *').forEach(function(element){ cascadeText(element, {}); });
    gsap.utils.toArray('.brand__name, .site-nav__links a, .nav-action span, .nav-toggle span, .button span, .quiet-link span').forEach(function(element, index){ cascadeText(element, {from:'start', delay:index*.03}); });
    if(finePointer){
      gsap.utils.toArray('.button span, .nav-action span, .quiet-link span').forEach(function(label){
        var chars=label.querySelectorAll('.st-char');
        var wave;
        if(!chars.length) return;
        label.parentElement.addEventListener('mouseenter', function(){
          if(wave) wave.kill();
          wave=gsap.timeline().to(chars, {y:-6, duration:.2, ease:'power2.out', stagger:.018}).to(chars, {y:0, duration:.55, ease:'elastic.out(1,.5)', stagger:.018}, '-=.24');
        });
      });
    }
    if(hasScramble){
      var pool='有据可依更好的生活出处结构追问理性分享※○△□◇◈/';
      gsap.utils.toArray('.eyebrow > span').forEach(function(element){
        var finalText=element.textContent;
        ScrollTrigger.create({trigger:element, start:'top 88%', once:true, onEnter:function(){ gsap.to(element, {duration:1, scrambleText:{text:finalText, chars:pool, speed:.35}, onComplete:function(){ element.textContent=finalText; }}); }});
      });
    }
  }
  if(document.fonts && document.fonts.ready){ document.fonts.ready.then(function(){ initType(); ScrollTrigger.refresh(); }); } else initType();

  /* ---------- Reveals ---------- */
  gsap.utils.toArray('.reveal, [data-reveal]').forEach(function(element){
    gsap.fromTo(element, {y:38, autoAlpha:0}, {y:0, autoAlpha:1, duration:.85, ease:easeLift, scrollTrigger:{trigger:element, start:'top 86%', toggleActions:'play none none none', onEnter:function(){ gsap.set(element, {willChange:'transform, opacity'}); }}, onStart:function(){ gsap.set(element, {willChange:'transform, opacity'}); }, onComplete:function(){ gsap.set(element, {willChange:'auto'}); }});
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
    if(featureDescription){
      featureDescription.textContent = featureDescriptions[index];
      featureDescription.removeAttribute('data-motion-split');
      cascadeText(featureDescription, {});
    }
    if(featureNumber) gsap.fromTo(featureNumber, {y:-8, opacity:.35}, {y:0, opacity:1, duration:.45, ease:easeBack, overwrite:true});
    var activeLabel = featureTabs[index] && featureTabs[index].querySelectorAll('.st-char');
    if(activeLabel && activeLabel.length){
      gsap.fromTo(activeLabel, {yPercent:function(){ return gsap.utils.random(35,85); }, opacity:.25}, {yPercent:0, opacity:1, duration:.56, ease:easeBack, stagger:.025, overwrite:'auto'});
    }
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
