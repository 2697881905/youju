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
  var darkZones = [], navH = 0;

  /* 暗色区间坐标只在 resize/load/字体就绪时测量一次；滚动帧内零 getBoundingClientRect（防每帧强制 layout） */
  function measureZones(){
    if(!nav) return;
    navH = nav.offsetHeight;
    darkZones = [];
    document.querySelectorAll('.features, .harmony, .download, .footer').forEach(function(section){
      darkZones.push({ top: section.offsetTop, bottom: section.offsetTop + section.offsetHeight });
    });
  }

  function syncNav(){
    if(!nav) return;
    var edge = window.scrollY + navH + 12;
    var dark = false;
    for(var i = 0; i < darkZones.length; i++){
      if(darkZones[i].top <= edge && darkZones[i].bottom > edge){ dark = true; break; }
    }
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
  window.addEventListener('resize', function(){ measureZones(); syncNav(); });
  measureZones();
  syncNav();

  var videos = document.querySelectorAll('.device-video');
  if('IntersectionObserver' in window && videos.length){
    var playingVideo = null;
    var videoObserver = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if(entry.isIntersecting && !reduce){
          if(playingVideo && playingVideo !== entry.target) playingVideo.pause();  /* 同屏互斥：解码两段视频必掉帧 */
          playingVideo = entry.target;
          entry.target.play().catch(function(){});
        }
        else entry.target.pause();
      });
    }, {threshold:.35});
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

  /* ---------- Hero entrance and atmosphere ---------- */
  gsap.timeline({defaults:{ease:'power3.out'}})
    .fromTo('.site-nav', {y:-18, autoAlpha:0}, {y:0, autoAlpha:1, duration:.65}, .05)
    .fromTo('.hero__copy .eyebrow', {y:20, autoAlpha:0}, {y:0, autoAlpha:1, duration:.65}, .14)
    .fromTo('.hero__lead, .hero__actions', {y:26, autoAlpha:0}, {y:0, autoAlpha:1, duration:.8, stagger:.1}, .42)
    .fromTo('.hero__stage', {y:50, autoAlpha:0, scale:.94}, {y:0, autoAlpha:1, scale:1, duration:1.1}, .24);
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
    var timeline = gsap.timeline({delay:options && options.delay || 0, scrollTrigger:options && options.scrollTrigger});
    chars.forEach(function(char, index){
      var motion = motionFor(index);
      timeline.to(char, {
        x:0, yPercent:0, z:0, rotationX:0, rotationY:0, rotate:0, skewX:0, scale:1, opacity:1,
        duration:gsap.utils.random(motion.duration[0], motion.duration[1]), ease:motion.ease, overwrite:'auto',
        /* 字符起飞时才提升合成层、落位即释放——避免快滚穿越多区时全量字符层同时存活 */
        onStart:function(){ char.style.willChange='transform, opacity'; },
        onComplete:function(){ char.style.willChange='auto'; }
      }, gsap.utils.random(0, 1.65));
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
    if(options && options.immediate){
      gsap.set(chars, Object.assign(charFrom(), {display:'inline-block', transformOrigin:'50% 100%', transformPerspective:800, force3D:true, backfaceVisibility:'hidden'}));
      /* 首屏标题同样四向：离开视口倒放复位，滚回重播 */
      animateChars(chars, {delay:options.delay || .16, scrollTrigger:{trigger:element, start:'top 96%', toggleActions:'restart none restart none'}});
    }else{
      gsap.set(chars, Object.assign(charFrom(), {display:'inline-block', transformOrigin:'50% 100%', transformPerspective:800, force3D:true, backfaceVisibility:'hidden'}));
      /* 四向跟随滑动：任意方向进入视口 restart 重播，任意方向离开 reverse 倒放复位 */
      animateChars(chars, {scrollTrigger:{trigger:element, start:'top 86%', toggleActions:'restart none restart none'}});
    }
    if(options && options.interactive !== false) pointerAndClick(element, chars);
  }

  var hasPinyin = typeof window.pinyinPro !== 'undefined' && typeof window.pinyinPro.pinyin === 'function';
  function pinyinOf(glyph){
    try{ return window.pinyinPro.pinyin(glyph, {toneType:'none', type:'array'})[0] || ''; }
    catch(e){ return ''; }
  }

  function cascadeText(element, options){
    if(!element || !hasSplit || element.dataset.motionSplit) return;
    if(element._typingTrigger) element._typingTrigger.kill();
    element.dataset.motionSplit='true';
    var typewriter = options && options.typewriter;
    if(typewriter) element.classList.add('typewriter-copy');
    var split = new window.SplitText(element, {type:'chars', charsClass:'st-char', ignore:'br'});
    var chars = split.chars || [];
    if(!chars.length) return;
    var each = options && options.each || (typewriter ? (chars.length > 48 ? .034 : .045) : (chars.length > 48 ? .022 : .032));
    var caret = null, ghost = null, charRects = null, typing = null;
    function cleanupExtras(){
      if(caret && caret.parentNode) caret.parentNode.removeChild(caret);
      if(ghost && ghost.parentNode) ghost.parentNode.removeChild(ghost);
      caret = ghost = null;
      element.classList.remove('is-typing');
    }
    gsap.set(chars, {
      display:'inline-block',
      x:function(){ return gsap.utils.random(typewriter ? -2.6 : -2, typewriter ? 2.6 : 2); },
      yPercent:function(){ return gsap.utils.random(typewriter ? 6 : 0, typewriter ? 14 : 4); },
      scale:function(){ return gsap.utils.random(typewriter ? .96 : .96, typewriter ? .985 : 1); },
      opacity:function(){ return gsap.utils.random(0,.04); }
    });
    var scrollCfg = options.immediate ? undefined : {trigger:element, start:'top 88%', toggleActions:'restart none restart none'};
    var buildTyping = function(){
      cleanupExtras();
      /* 打字机字符动画幅度极小（±2px/淡入），不提升合成层——整段 will-change 会造成几十个层同时存活的层爆炸 */
      if(typewriter){
        typing = gsap.timeline({
          scrollTrigger:scrollCfg,
          onStart:function(){
            element.classList.add('is-typing');
            charRects = chars.map(function(char){ return { x:char.offsetLeft, y:char.offsetTop, w:char.offsetWidth, h:char.offsetHeight }; });
          },
          onComplete:cleanupExtras,
          onReverseComplete:function(){ cleanupExtras(); }
        });
        var cursor = options && options.delay || 0;
        var breathEvery = Math.round(gsap.utils.random(6,10));
        chars.forEach(function(char, index){
          var glyph = char.textContent || '';
          var punctuation = /[，。！？；：、,.!?;:]/.test(glyph);
          var py = (pinyinOf && /[\u4e00-\u9fff]/.test(glyph)) ? pinyinOf(glyph) : '';
          typing.call(function(){
            /* 光标在此处惰性诞生（首次打字位置），restart 复用同一节点——杜绝多光标 */
            if(!caret){ caret = document.createElement('span'); caret.className='type-caret'; element.appendChild(caret); }
            var rect = charRects[index];
            caret.style.height = Math.max(12, rect.h * .8).toFixed(1) + 'px';
            caret.style.transform = 'translate(' + rect.x.toFixed(1) + 'px,' + (rect.y + rect.h * .1).toFixed(1) + 'px)';
          });
          if(py){
            typing.call(function(){
              if(!ghost){ ghost = document.createElement('span'); ghost.className='pinyin-ghost'; element.appendChild(ghost); }
              var rect = charRects[index];
              ghost.style.width = rect.w.toFixed(1) + 'px';
              ghost.style.height = rect.h.toFixed(1) + 'px';
              ghost.style.transform = 'translate(' + rect.x.toFixed(1) + 'px,' + rect.y.toFixed(1) + 'px)';
              ghost.style.opacity = 1;
            });
            var letterDur = gsap.utils.random(.045, .065);
            var pyDur = py.length * letterDur;
            /* 逐字母显示用单个 proxy tween 驱动（聚合 N 个 call，降低 timeline 结构成本） */
            var pyProxy = { n: 0 };
            typing.to(pyProxy, {
              n: py.length, duration: pyDur, ease: 'none',
              onUpdate: function(){ ghost.textContent = py.slice(0, Math.round(pyProxy.n)); }
            }, cursor);
            if(punctuation) cursor += gsap.utils.random(.06, .12);
            if(index && index % breathEvery === 0) cursor += gsap.utils.random(.028, .07);
            /* 汉字在拼音后半段开始成形，拼音消失后立即落定——过程可见且无停顿割裂 */
            typing.to(char, {x:0, yPercent:0, scale:1, opacity:1, duration:pyDur * .4 + .12, ease:'power2.out', overwrite:'auto'}, cursor + pyDur * .6);
            typing.to(ghost, {opacity:0, duration:.07, ease:'none'}, cursor + pyDur);
            cursor += pyDur + .05;
          }else{
            cursor += gsap.utils.random(.026,.052);
            if(index && index % breathEvery === 0) cursor += gsap.utils.random(.028,.07);
            if(punctuation) cursor += gsap.utils.random(.1,.24);
            typing.to(char, {x:0, yPercent:0, scale:1, opacity:1, duration:gsap.utils.random(.075,.145), ease:'power2.out', overwrite:'auto'}, cursor);
          }
        });
      }else{
        typing = gsap.timeline({delay:options && options.delay || 0});
        typing.to(chars, {
          x:0, yPercent:0, scale:1, opacity:1, duration:.1, ease:'none',
          stagger:{each:each, from:options && options.from || 'start'}, overwrite:'auto'
        });
        typing.eventCallback('onComplete', cleanupExtras);
        typing.eventCallback('onReverseComplete', cleanupExtras);
      }
    };
    buildTyping();
  }

  function initType(){
    if(!hasSplit){ gsap.set('.hero__title', {autoAlpha:1}); return; }
    splitHeading(document.querySelector('.hero__title'), {immediate:true, delay:.2});
    gsap.utils.toArray('.section-heading h2, .scenes__intro h2, .harmony__copy h3, .download h2, .principle h3, .scene-panel__copy h3').forEach(function(element){ splitHeading(element, {interactive:true}); });
    gsap.utils.toArray('.hero__lead, .section-heading > p:last-child, .scenes__intro > p:last-child, .feature-card__copy p, .scene-panel__copy p, .harmony__copy p, .download__copy > p:last-of-type').forEach(function(element){ cascadeText(element, {typewriter:true}); });
    /* 并排三卡打字错峰依次进行，避免多光标同屏闪烁 */
    gsap.utils.toArray('.principle p').forEach(function(element, index){ cascadeText(element, {typewriter:true, delay:index * 1.15}); });
    gsap.utils.toArray('.feature-card__copy span, .scene-panel__copy > b, .announcement__label').forEach(function(element){ cascadeText(element, {}); });
    gsap.utils.toArray('.brand__name, .site-nav__links a, .nav-action span, .nav-toggle span, .mobile-menu a > span, .button span, .quiet-link span').forEach(function(element, index){ cascadeText(element, {from:'start', delay:index*.03}); });
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
        ScrollTrigger.create({trigger:element, start:'top 88%', once:true, onEnter:function(){ gsap.to(element, {duration:1, scrambleText:{text:finalText, chars:pool, speed:.35}, onComplete:function(){ element.textContent=finalText; cascadeText(element, {immediate:true, each:.04}); }}); }});
      });
    }else gsap.utils.toArray('.eyebrow > span').forEach(function(element){ cascadeText(element, {each:.04}); });
  }
  if(document.fonts && document.fonts.ready){ document.fonts.ready.then(function(){ initType(); ScrollTrigger.refresh(); measureZones(); }); } else initType();

  /* ---------- Reveals（四向：进入正放，从上方滚回重播，离开倒放复位） ---------- */
  gsap.utils.toArray('.reveal, [data-reveal]').forEach(function(element){
    gsap.fromTo(element, {y:38, autoAlpha:0}, {y:0, autoAlpha:1, duration:.85, ease:easeLift, scrollTrigger:{trigger:element, start:'top 86%', toggleActions:'play none restart none', onEnter:function(){ gsap.set(element, {willChange:'transform, opacity'}); }}, onStart:function(){ gsap.set(element, {willChange:'transform, opacity'}); }, onComplete:function(){ gsap.set(element, {willChange:'auto'}); }});
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

  /* ---------- Continuous horizontal story（features 能力卡 + scenes 场景卡，同一套横移机制） ---------- */
  var scenes = document.querySelector('.scenes');
  var track = document.querySelector('.scenes__track');
  var features = document.querySelector('.features');
  var featureTrack = document.querySelector('.feature-track');
  if(scenes && track){
    ScrollTrigger.matchMedia({
      '(min-width: 901px)': function(){
        var horizontal = gsap.to(track, {x:function(){ return -(track.scrollWidth - window.innerWidth); }, ease:'none', scrollTrigger:{trigger:scenes, start:'top top', end:function(){ return '+=' + Math.max(1700, track.scrollWidth - window.innerWidth + 260); }, scrub:1, pin:true, anticipatePin:1}});
        gsap.utils.toArray('.scene-panel').forEach(function(panel){
          gsap.fromTo(panel.querySelector('.scene-panel__copy'), {x:90, autoAlpha:.2}, {x:0, autoAlpha:1, ease:'none', scrollTrigger:{trigger:panel, containerAnimation:horizontal, start:'left 78%', end:'left 38%', scrub:.7}});
          gsap.fromTo(panel.querySelector('.device'), {scale:.78, rotation:panel.classList.contains('scene-panel--white') ? -8 : 8, autoAlpha:.55}, {scale:1, rotation:0, autoAlpha:1, ease:'none', scrollTrigger:{trigger:panel, containerAnimation:horizontal, start:'left 82%', end:'left 35%', scrub:.8}});
        });
        return function(){ if(horizontal.scrollTrigger) horizontal.scrollTrigger.kill(); horizontal.kill(); gsap.set(track, {clearProps:'transform'}); };
      },
      '(max-width: 900px)': function(){
        /* 移动端：纵向滚动驱动横向位移（不做 pin，规避地址栏高度抖动） */
        var mobile = gsap.to(track, {
          x: function(){ return -(track.scrollWidth - window.innerWidth); },
          ease: 'none',
          scrollTrigger: { trigger: scenes, start: 'top top', end: 'bottom bottom', scrub: .6, invalidateOnRefresh: true }
        });
        return function(){ if(mobile.scrollTrigger) mobile.scrollTrigger.kill(); mobile.kill(); gsap.set(track, {clearProps:'transform'}); };
      }
    });
  }
  if(features && featureTrack){
    ScrollTrigger.matchMedia({
      '(min-width: 901px)': function(){
        var fHorizontal = gsap.to(featureTrack, {x:function(){ return -(featureTrack.scrollWidth - window.innerWidth); }, ease:'none', scrollTrigger:{trigger:features, start:'top top', end:function(){ return '+=' + Math.max(1500, featureTrack.scrollWidth - window.innerWidth + 240); }, scrub:1, pin:true, anticipatePin:1}});
        gsap.utils.toArray('.feature-card').forEach(function(card, index){
          gsap.fromTo(card, {autoAlpha:.35}, {autoAlpha:1, ease:'none', scrollTrigger:{trigger:card, containerAnimation:fHorizontal, start:'left 85%', end:'left 45%', scrub:.7}});
        });
        return function(){ if(fHorizontal.scrollTrigger) fHorizontal.scrollTrigger.kill(); fHorizontal.kill(); gsap.set(featureTrack, {clearProps:'transform'}); };
      },
      '(max-width: 900px)': function(){
        var fMobile = gsap.to(featureTrack, {
          x: function(){ return -(featureTrack.scrollWidth - window.innerWidth); },
          ease: 'none',
          scrollTrigger: { trigger: features, start: 'top top', end: 'bottom bottom', scrub: .6, invalidateOnRefresh: true }
        });
        return function(){ if(fMobile.scrollTrigger) fMobile.scrollTrigger.kill(); fMobile.kill(); gsap.set(featureTrack, {clearProps:'transform'}); };
      }
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

  window.addEventListener('load', function(){ ScrollTrigger.refresh(); measureZones(); syncNav(); });
})();
