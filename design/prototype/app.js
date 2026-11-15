/* Local interaction prototype. No network, audio playback, or provider calls. */
(() => {
'use strict';
const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const paths = {
 lens:'<path d="M5 5h5v14H5zM14 3h5v18h-5z"/><path d="M8 9v6m8-9v12"/>',
 home:'<path d="m3 10 9-7 9 7v10H3zM9 20v-7h6v7"/>',
 compass:'<circle cx="12" cy="12" r="9"/><path d="m16 8-3 5-5 3 3-5z"/>',
 clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
 grid:'<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
 download:'<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
 settings:'<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3"/><circle cx="15" cy="17" r="3"/>',
 plus:'<path d="M12 4v16M4 12h16"/>',
 play:'<path d="m9 5 10 7-10 7z"/>',pause:'<path d="M8 5v14M16 5v14"/>',
 book:'<path d="M12 5v15M3 4c4-1 7 0 9 2 2-2 5-3 9-2v15c-4-1-7 0-9 2-2-2-5-3-9-2z"/>',
 arrow:'<path d="M4 12h16m-6-6 6 6-6 6"/>',
 replay:'<path d="M4 9a8 8 0 1 1 0 6M4 3v6h6"/>',
 moon:'<path d="M20 14A9 9 0 0 1 10 3a9 9 0 1 0 10 11z"/>',
 search:'<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/>',
 check:'<path d="m5 12 4 4L20 5"/>',menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
 focus:'<path d="M9 3H3v6m12-6h6v6M3 15v6h6m6 0h6v-6"/>',
 close:'<path d="m5 5 14 14M19 5 5 19"/>',
 sun:'<circle cx="12" cy="12" r="4"/><path d="M12 1v2m0 18v2M1 12h2m18 0h2M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2"/>'
};
const icon = name => `<svg class="od-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.book}</svg>`;
const shows = [
 {id:'td',name:'The Design Details',cover:'Design<br>Details',tag:'Design & craft',category:'设计',description:'关于设计、细节，以及软件背后的取舍。'},
 {id:'ds',name:'Deep Sky Notes',cover:'Deep<br>Sky',tag:'Beyond the visible',category:'科学',description:'从星系到星云，探索那些遥远的光。'},
 {id:'mc',name:'Machine, Carefully',cover:'Machine,<br>Carefully',tag:'Thoughtful technology',category:'科技',description:'理解模型评估，以及数字之外的判断。'},
 {id:'lg',name:'The Long Game',cover:'The Long<br>Game',tag:'Ideas over time',category:'访谈',description:'关于耐心、长期主义与不引人注目的积累。'}
];
const episodes = [
 {id:'interfaces',show:'td',title:'Why the best interfaces disappear',duration:3240,date:'11月2日',ready:true,downloaded:true,desc:'好的界面如何用排版、默认值与克制，让内容成为主角。'},
 {id:'empty',show:'td',title:'An empty state should explain the next action',duration:2880,date:'11月6日',ready:false,downloaded:true,desc:'空状态不只解释发生了什么，更要告诉用户下一步。'},
 {id:'sky',show:'ds',title:'The light that left before the stars',duration:2160,date:'11月4日',ready:false,downloaded:true,desc:'沿着遥远的光，回溯星空的故事。'},
 {id:'evaluation',show:'mc',title:'What evaluation actually measures',duration:3660,date:'10月31日',ready:false,downloaded:false,desc:'评估数字能够解释什么，又遗漏了什么。'},
 {id:'boring',show:'lg',title:'Boring advantages',duration:2760,date:'10月30日',ready:false,downloaded:false,desc:'耐心与不显眼的工作，如何在时间里积累价值。'},
 {id:'measure',show:'td',title:'Line height and measure decide whether people stay',duration:3120,date:'10月28日',ready:false,downloaded:false,desc:'从行高与栏宽开始，重新理解阅读节奏。'},
 {id:'defaults',show:'td',title:'Defaults are the most honest part of a product',duration:3240,date:'10月21日',ready:false,downloaded:false,desc:'每一个默认值，都藏着产品对用户的理解。'}
];
const sentences = [
 [0,'Good design is mostly subtraction.','好的设计大多是做减法。'],
 [6,'Every control you add asks the listener for attention.','每多一个控件，就多向听众索取一次注意力。'],
 [13,'The interface should hold the episode, not compete with it.','界面应该托住这一集内容，而不是与它竞争。'],
 [21,'Typography does the quiet work that color cannot.','字体在默默完成颜色做不到的工作。'],
 [29,'A transcript is a reading surface, so set it like one.','逐句稿是阅读界面，就该按阅读来排版。'],
 [37,'Line height and measure decide whether people stay.','行高与栏宽决定了人是否愿意留下来。'],
 [45,'Then the player can be small, because the words are large.','播放器可以很小，因为文字足够大。'],
 [53,'Defaults are the most honest part of a product.','默认状态是一个产品最诚实的部分。'],
 [61,'An empty state should explain the next action, not apologize.','空状态应该说明下一步，而不是道歉。'],
 [69,'Chapter marks let you return to the sentence that mattered.','章节标记让你随时回到重要的那句话。']
];
const defaults = {page:document.body.dataset.page || 'home',episode:'interfaces',positions:{interfaces:38},reading:37,language:'bilingual',follow:true,rate:1,dark:false,subscriptions:['td','ds','mc','lg'],job:'processing',prefs:{base:'https://api.openai.com/v1',chat:'gpt-4o-mini',asr:'whisper-1',refresh:'30',auto:true},heard:[]};
let saved = {};
try { saved = JSON.parse(localStorage.getItem('podlens-prototype-v2') || '{}') || {}; } catch (_) { /* Storage is optional in previews. */ }
const state = {...defaults,...saved,page:document.body.dataset.page || 'home',playing:false,focus:false,filter:'all',show:null,query:'',sleep:0};
state.positions = {...defaults.positions,...saved.positions};
state.prefs = {...defaults.prefs,...saved.prefs};
let memoryOnly = false;
function persist() {
 const {playing,page,focus,filter,show,query,sleep,...data} = state;
 try { localStorage.setItem('podlens-prototype-v2',JSON.stringify(data)); } catch (_) { memoryOnly = true; }
}
const getEpisode = () => episodes.find(e => e.id === state.episode) || episodes[0];
const getShow = id => shows.find(s => s.id === id) || shows[0];
const time = s => `${String(Math.floor(s/60)).padStart(2,'0')}:${String(Math.floor(s%60)).padStart(2,'0')}`;
const position = () => state.positions[getEpisode().id] || 0;
const cover = (id,mini=false) => { const s=getShow(id);return `<div class="cover ${id}${mini?' mini':''}" aria-label="${escape(s.name)} 示例封面"><small>${s.tag}</small><strong>${mini?id.toUpperCase():s.cover}</strong><span class="cover-line"></span></div>`; };
const button = (text,action,cls='',attrs='') => `<button type="button" class="btn ${cls}" data-action="${action}" ${attrs}>${text}</button>`;
const navButton = (label,page,glyph,attrs='') => `<button type="button" class="nav-btn ${state.page===page && !state.show?'active':''}" data-page="${page}" ${attrs}>${icon(glyph)}<span>${label}</span></button>`;
function sidebar() {
 return `<aside class="sidebar" aria-label="主导航"><button type="button" class="brand" data-page="home" style="border:0;background:none;text-align:left"><span class="brand-mark">${icon('lens')}</span>PodLens</button>
 <nav class="nav-group">${navButton('主页','home','home')}${navButton('发现','discover','compass')}</nav>
 <nav class="nav-group"><div class="nav-title">资料库</div>${navButton('最近更新','episodes','clock','data-filter="all"')}${navButton('节目','episodes','grid','data-filter="shows"')}${navButton('已下载','episodes','download','data-filter="downloaded"')}</nav>
 <nav class="nav-group"><div class="nav-title">我的订阅</div>${shows.filter(s=>state.subscriptions.includes(s.id)).map(s=>`<button type="button" class="nav-btn ${state.show===s.id?'active':''}" data-page="episodes" data-show="${s.id}">${cover(s.id,true)}<span class="od-field od-fill"><span class="od-truncate">${s.name}</span><span class="sub">${s.category}</span></span></button>`).join('')}${button(`${icon('plus')} 添加订阅`,'discover','text')}</nav>
 <div class="side-bottom">${navButton('设置','settings','settings')}<p>本地交互原型 · 不连接 API</p></div></aside>`;
}
function player() {
 const ep=getEpisode(); const s=getShow(ep.show);
 return `<footer class="player" aria-label="播放器"><button type="button" class="now-playing" data-action="open-current" aria-label="打开当前单集">${cover(ep.show,true)}<span class="od-field"><span class="od-truncate">${escape(ep.title)}</span><small class="od-truncate">${s.name}</small></span></button>
 <div class="player-center"><div class="transport"><button type="button" data-action="back" aria-label="快退15秒">−15</button><button type="button" class="play" data-action="toggle" aria-label="${state.playing?'暂停':'开始'}演示进度">${icon(state.playing?'pause':'play')}</button><button type="button" data-action="forward" aria-label="快进30秒">+30</button></div>
 <div class="player-range"><span data-time>${time(position())}</span><input id="seek" type="range" min="0" max="${ep.duration}" value="${position()}" aria-label="演示播放位置"><span data-remaining>−${time(ep.duration-position())}</span></div></div>
 <div class="player-extras"><label><span class="sr-only">播放倍速</span><select id="rate" aria-label="播放倍速">${[1,1.25,1.5,2,2.5,3].map(v=>`<option ${state.rate===v?'selected':''} value="${v}">${v}×</option>`).join('')}</select></label><select id="sleep" aria-label="睡眠定时">${[[0,'定时关闭'],[5,'5 分钟'],[15,'15 分钟'],[30,'30 分钟']].map(([v,t])=>`<option value="${v}" ${state.sleep===v?'selected':''}>${t}</option>`).join('')}</select><span class="meta">演示进度</span></div></footer>`;
}
function row(ep) {
 const s=getShow(ep.show); const current=state.episode===ep.id;
 return `<article class="episode-row">${cover(ep.show)}<div class="od-fill"><button type="button" class="episode-title" data-action="open" data-id="${ep.id}">${escape(ep.title)}</button><div class="meta">${s.name} · ${ep.date} · ${ep.duration/60} 分钟${state.heard.includes(ep.id)?' · 已听完':''}</div><div class="chips">${ep.downloaded?'<span class="chip">已下载 · 示例</span>':''}${ep.ready?`<span class="chip ready">${icon('check')} 双语稿就绪</span>`:ep.id==='sky'?`<span class="chip pending">${state.job==='processing'?'转写中 · 演示 46%':'已取消'}</span>`:'<span class="chip">未生成逐句稿</span>'}</div></div><div class="row-actions">${ep.id==='sky'&&state.job==='processing'?button('取消','cancel-job','','data-id="sky"'):''}${button(icon(current&&state.playing?'pause':'play'),'play-episode','','data-id="'+ep.id+'" aria-label="'+(current&&state.playing?'暂停':'播放')+' '+escape(ep.title)+'"')}${ep.ready?button('逐句稿','open','','data-id="'+ep.id+'"'):button('一键听懂','generate','text','data-id="'+ep.id+'"')}</div></article>`;
}
function showTiles() {
 return `<div class="show-grid">${shows.filter(s=>state.subscriptions.includes(s.id)).map(s=>`<button type="button" class="show-tile" data-page="episodes" data-show="${s.id}">${cover(s.id)}<span class="od-field"><span class="od-clamp-2">${s.name}</span><small>${episodes.filter(e=>e.show===s.id).length} 集示例</small></span></button>`).join('')}</div>`;
}
function home() {
 const ep=getEpisode(),s=getShow(ep.show),p=position();
 return `<div class="page-heading"><div><h1>接着听，慢慢懂。</h1><p>让声音与文字，停留在同一个地方。</p></div>${button(`${icon('plus')} 添加订阅`,'discover')}</div>
 <section class="hero"><div><div class="eyebrow">继续收听</div><h2>${escape(ep.title)}</h2><div class="meta">${s.name} · ${ep.duration/60} 分钟</div><div class="progress-line"><progress data-hero-progress max="${ep.duration}" value="${p}" aria-label="收听进度"></progress><small data-hero-time>${time(p)} / ${time(ep.duration)}</small></div>
 <div class="actions">${button(`${icon(state.playing?'pause':'play')} <span data-toggle-label>${state.playing?'暂停':'继续收听'}</span>`,'toggle','primary')}${button(`${icon('book')} ${ep.ready?'回到逐句稿':'查看单集'}`,'open-current')}${button(`${icon('replay')} 从头重听`,'restart','text')}</div>
 <div class="resume-line">${icon('book')}<div>${ep.ready?`上次读到 <strong>${time(state.reading)}</strong><p>${escape((sentences.find(s=>s[0]===state.reading)||sentences[5])[2])}</p>`:'这集还没有逐句稿<p>可先体验播放控制，再查看生成流程。</p>'}</div></div></div>${cover(ep.show)}</section>
 <section class="section"><div class="section-head"><h2>最近更新 <small>来自你的订阅</small></h2>${button(`查看全部 ${icon('arrow')}`,'all-episodes','text')}</div>${episodes.filter(e=>state.subscriptions.includes(e.show)).slice(1,4).map(row).join('')}</section>
 <section class="section"><div class="section-head"><h2>我的节目</h2><small>${state.subscriptions.length} 档订阅</small></div>${state.subscriptions.length?showTiles():'<p class="notice">还没有订阅。到发现页添加一档节目，开始收听。</p>'}</section>`;
}
function listPage() {
 if(state.filter==='shows') return `<div class="page-heading"><div><h1>我的节目</h1><p>${state.subscriptions.length} 档订阅 · 选择节目查看单集</p></div></div>${showTiles()}`;
 const show=state.show?getShow(state.show):null;
 const list=episodes.filter(e=>(show?e.show===show.id:state.subscriptions.includes(e.show))&&(state.filter!=='downloaded'||e.downloaded));
 return `<div class="page-heading"><div><h1>${show?show.name:state.filter==='downloaded'?'已下载':'最近更新'}</h1><p>${list.length} 集示例${show?' · '+show.description:' · 播放与内容处理互不阻塞'}</p></div></div><div class="detail-tools"><div class="tabs">${[['all','全部'],['downloaded','已下载']].map(([id,label])=>`<button class="tab ${state.filter===id?'active':''}" data-action="filter" data-filter="${id}">${label}</button>`).join('')}</div><span class="od-fill"></span>${button('全部标为已听','mark-heard','text')}</div>${list.length?list.map(row).join(''):'<div class="empty"><h2>还没有下载内容</h2><p>此原型只展示已有下载示例，不进行真实下载。</p></div>'}`;
}
function detailHeader() {
 const ep=getEpisode();return `<div class="detail-heading">${cover(ep.show)}<div class="od-fill"><div class="eyebrow">${getShow(ep.show).name}</div><h1>${escape(ep.title)}</h1><div class="meta">${ep.date} · ${ep.duration/60} 分钟 · ${ep.ready?'双语内容示例已就绪':'逐句稿尚未生成'}</div></div><button type="button" class="icon-btn" data-action="focus" aria-label="${state.focus?'退出':'进入'}专注模式" title="专注模式 F">${icon(state.focus?'close':'focus')}</button></div>`;
}
function transcript() {
 const ep=getEpisode();
 return `${detailHeader()}<div class="detail-tools"><nav class="tabs" aria-label="单集内容"><button class="tab active" data-page="transcript">逐句稿</button><button class="tab" data-page="summary">总结</button></nav><div class="segmented" aria-label="阅读语言">${[['bilingual','双语'],['translation','译文'],['original','原文']].map(([id,label])=>`<button type="button" data-action="language" data-language="${id}" aria-pressed="${state.language===id}" class="${state.language===id?'active':''}">${label}</button>`).join('')}</div><div class="tool-end">${button('跟随 '+(state.follow?'开':'关'),'follow','',`aria-pressed="${state.follow}"`)}${button('当前句','current','text')}</div></div>
 ${ep.ready?`<div class="reading" data-language="${state.language}"><p class="reading-note">点击一句，定位演示进度。当前仅提供开头 01:09 的示例文本，无真实音频。</p>${sentences.map(([sec,en,zh])=>`<div class="sentence ${sec===state.reading?'current':''}" role="button" tabindex="0" data-action="sentence" data-sec="${sec}" aria-label="定位到 ${time(sec)} ${escape(zh)}"><span class="stamp">${time(sec)}</span><div><div class="en" lang="en">${en}</div><div class="zh">${zh}</div></div></div>`).join('')}<div class="reading-footer"><span><kbd>Space</kbd> 开始 / 暂停</span><span><kbd>Ctrl / ⌘ ← →</kbd> −15 / +30 秒</span><span><kbd>F</kbd> 专注阅读</span></div></div>`:`<div class="empty"><h2>让这集内容，也能读懂</h2><p>逐句稿尚未生成，播放控制仍可使用。</p>${button('了解生成流程','generate','','data-id="'+ep.id+'"')}</div>`}`;
}
function summary() {
 const ep=getEpisode();return `${detailHeader()}<div class="detail-tools"><nav class="tabs" aria-label="单集内容"><button class="tab" data-page="transcript">逐句稿</button><button class="tab active" data-page="summary">总结</button></nav><span class="od-fill"></span>${button('回到当前句','current','text')}</div>${ep.ready?`<div class="reading"><p class="reading-note">以下为示例文本的内容提要，未调用模型生成。时间锚点可返回原句。</p><section class="summary-section"><h2>一句话总结</h2><p class="tldr">好的界面靠做减法赢得注意力，让排版、默认值与清晰的引导，安静地托住内容。</p></section><section class="summary-section"><h2>值得带走的要点</h2>${[[6,'每多一个控件，就多索取一次注意力。'],[29,'把逐句稿当作真正的阅读界面，认真对待行高与栏宽。'],[53,'每一个默认值，都应该有清楚的理由。'],[61,'空状态应当说明下一步。']].map(([sec,t],i)=>`<div class="point"><span class="number">0${i+1}</span><div class="od-fill"><p>${t}</p>${button(`${time(sec)} ${icon('arrow')} 查看原句`,'anchor','text',`data-sec="${sec}"`)}</div></div>`).join('')}</section><section class="summary-section"><h2>值得重听的话</h2>${[4,7].map(i=>`<blockquote class="quote"><p lang="en">“${sentences[i][1]}”</p><small>${sentences[i][2]}</small>${button(`${icon('play')} 从 ${time(sentences[i][0])} 重听`,'anchor','text',`data-sec="${sentences[i][0]}"`)}</blockquote>`).join('')}</section><section class="summary-section"><h2>话题</h2><div class="chips"><span class="chip">设计系统</span><span class="chip">排版</span><span class="chip">默认值</span><span class="chip">空状态</span></div></section></div>`:'<div class="empty"><h2>这集还没有总结</h2><p>生成逐句稿后，才有可以回溯到原句的内容提要。</p>'+button('了解生成流程','generate','','data-id="'+ep.id+'"')+'</div>'}`;
}
function discover() {
 const q=state.query.toLowerCase().trim(); const result=shows.filter(s=>`${s.name} ${s.category} ${s.description}`.toLowerCase().includes(q));
 return `<div class="page-heading"><div><h1>发现下一段好内容</h1><p>先从双语示例开始，配置服务可以稍后再做。</p></div></div><div class="notice">${state.subscriptions.length?'已订阅 '+state.subscriptions.length+' 档示例节目。':'还没有订阅。选择一档节目，点击添加即可开始。'} 此处搜索仅筛选本地示例，不连接播客目录。</div><label class="search-field">${icon('search')}<input id="search" type="search" value="${escape(state.query)}" placeholder="搜索节目名称或主题" aria-label="搜索示例节目"></label><div id="search-results">${discoverResults(result)}</div>`;
}
function discoverResults(result) {
 return result.length?`<div class="discover-grid">${result.map(s=>`<article class="discover-card"><div class="od-row">${cover(s.id)}<div class="od-fill"><h2>${s.name}</h2><div class="meta">${s.category} · 示例节目</div></div></div><p>${s.description}</p><div class="actions">${button(`${icon(state.subscriptions.includes(s.id)?'check':'plus')} ${state.subscriptions.includes(s.id)?'已订阅':'添加订阅'}`,'subscribe','',`data-show="${s.id}" aria-pressed="${state.subscriptions.includes(s.id)}"`)}${button('查看单集','show','text',`data-show="${s.id}"`)}</div></article>`).join('')}</div>`:'<div class="empty"><h2>没有匹配的节目</h2><p>试试“设计”“科技”，或清空搜索查看全部示例。</p></div>';
}
function settings() {
 const p=state.prefs;
 const input=(id,label,value,type='text',help='')=>`<div class="form-row"><label for="${id}">${label}${help?`<small>${help}</small>`:''}</label><input id="${id}" type="${type}" value="${escape(value)}" autocomplete="off"></div>`;
 return `<div class="settings"><div class="page-heading"><div><h1>设置</h1><p>先听懂一集，再选择适合自己的服务。</p></div></div><div class="notice">这是交互原型。不会连接模型服务、产生费用或写入系统保险库。请勿输入真实密钥。</div><section class="settings-group"><h2>阅读与播放</h2><div class="form-row"><label for="theme-choice">外观<small>亮暗模式使用独立的对比色</small></label><select id="theme-choice"><option value="light" ${!state.dark?'selected':''}>浅色</option><option value="dark" ${state.dark?'selected':''}>深色</option></select></div><div class="form-row"><label for="auto-follow">自动跟随当前句<small>手动回看时，可以随时关闭</small></label><input id="auto-follow" type="checkbox" ${state.follow?'checked':''}></div></section>
 <section class="settings-group"><h2>模型服务</h2><p class="meta">使用自己的 API key。真实产品中的费用由所选服务商收取，播放不依赖此配置。</p>${input('base','服务地址',p.base,'url','使用兼容接口的 HTTPS 地址')}
 <div class="form-row"><label for="demo-key">API Key<small>仅演示掩码与显示，离开设置即清空</small></label><div class="od-row"><input id="demo-key" type="password" placeholder="请勿输入真实密钥" autocomplete="off">${button('显示','reveal')}</div></div><p class="meta">连接状态：未连接 · 密钥未保存</p><p id="settings-error" class="field-error" role="alert" hidden></p><div class="save-row">${button('检查填写格式','check-format')}${button('保存非敏感偏好','save-settings','primary')}</div><p id="settings-result" class="meta" role="status"></p>
 <details><summary>高级模型与处理选项</summary>${input('chat-model','聊天模型',p.chat,'text','用于翻译与总结')}${input('asr-model','转写模型',p.asr)}<div class="form-row"><label for="refresh">订阅自动刷新<small>原型仅保存偏好，不执行后台刷新</small></label><select id="refresh">${[['0','手动刷新'],['30','每 30 分钟'],['60','每小时']].map(([v,t])=>`<option value="${v}" ${p.refresh===v?'selected':''}>${t}</option>`).join('')}</select></div><div class="form-row"><label for="auto-update">自动检查更新<small>此原型不连接更新服务</small></label><input id="auto-update" type="checkbox" ${p.auto?'checked':''}></div></details></section>
 <section class="settings-group"><h2>本地数据</h2><p class="meta">${state.subscriptions.length} 档示例订阅 · ${episodes.length} 集示例内容。${memoryOnly?'当前预览不允许本地存储，状态仅在当前页面保留。':'阅读位置与非敏感偏好尝试保存在浏览器本地；若预览限制存储，仅在当前页面保留。'}</p></section></div>`;
}
const labels={home:'主页',episodes:'资料库',transcript:'逐句稿',summary:'总结',discover:'发现',settings:'设置'};
function render() {
 const focused=document.activeElement;
 const focusKey=focused?.dataset ? JSON.stringify(focused.dataset) : '';
 const focusId=focused?.id;
 const previousScroll=$('.main-scroll')?.scrollTop||0;
 document.documentElement.classList.toggle('dark',state.dark);
 document.title=`PodLens — ${labels[state.page]||'主页'}`;
 $('#app').className=`app${state.focus?' focus-mode':''}`;
 $('#app').innerHTML=`${sidebar()}<div class="workspace"><header class="topbar"><button type="button" class="icon-btn mobile-menu" data-action="menu" aria-label="打开导航" aria-expanded="false">${icon('menu')}</button><span class="breadcrumb">资料库 <span aria-hidden="true">/</span> ${labels[state.page]||'主页'}</span><span class="mode-label">示例内容 · 无真实音频</span><button type="button" class="icon-btn" data-action="theme" aria-label="切换到${state.dark?'浅色':'深色'}模式">${icon(state.dark?'sun':'moon')}</button></header><main class="main-scroll" id="main"><div class="content">${({home,episodes:listPage,transcript,summary,discover,settings}[state.page]||home)()}</div></main>${player()}</div>`;
 $('.main-scroll').scrollTop=previousScroll;
 if(focusId && document.getElementById(focusId)) document.getElementById(focusId).focus({preventScroll:true});
 else if(focusKey && focusKey!=='{}') {
  const replacement=$$('button,[role=button]').find(node=>JSON.stringify(node.dataset)===focusKey);
  replacement?.focus({preventScroll:true});
 }
 persist();
}
const scrollPositions={};
function navigate(page,opts={}) {
 scrollPositions[state.page]=$('.main-scroll')?.scrollTop||0;
 state.page=page; state.focus=page==='transcript'||page==='summary'?state.focus:false;
 if(page==='episodes') { state.show=opts.show||null;state.filter=opts.filter||'all'; } else state.show=null;
 render();$('.main-scroll').scrollTop=scrollPositions[page]||0;
 const heading=$('h1');if(heading){heading.tabIndex=-1;heading.focus({preventScroll:true});}
}
let noticeTimer;
function notify(message) { const el=$('#feedback');el.textContent=message;el.hidden=false;clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>{el.hidden=true;},4500); }
function syncPosition() {
 const p=position(),ep=getEpisode();
 $$('[data-time]').forEach(n=>n.textContent=time(p));$$('[data-remaining]').forEach(n=>n.textContent='−'+time(ep.duration-p));
 if($('#seek')) $('#seek').value=p;
 $$('[data-hero-progress]').forEach(n=>n.value=p);$$('[data-hero-time]').forEach(n=>n.textContent=`${time(p)} / ${time(ep.duration)}`);
 if(ep.ready&&p<=77&&state.follow){const current=[...sentences].reverse().find(s=>s[0]<=p)||sentences[0];const changed=state.reading!==current[0];state.reading=current[0];if(changed&&state.page==='transcript')$('.sentence[data-sec=\"'+current[0]+'\"]')?.scrollIntoView({block:'nearest',behavior:'smooth'});$$('.sentence').forEach(el=>el.classList.toggle('current',Number(el.dataset.sec)===current[0]));}
 persist();
}
function seek(value) { state.positions[getEpisode().id]=Math.max(0,Math.min(getEpisode().duration,value));syncPosition(); }
function toggle() {state.playing=!state.playing;render();if(state.playing)notify('正在演示进度变化，不播放真实音频。');}
function openEpisode(id) {state.episode=id;state.playing=false;persist();navigate('transcript');}
function currentSentence() {
 const sec=position();
 if(getEpisode().ready && sec<=77) {
  const current=[...sentences].reverse().find(sentence=>sentence[0]<=sec)||sentences[0];
  state.reading=current[0];
 }
 navigate('transcript');
 if(getEpisode().ready) {
  if(sec>77)notify('当前位置超出示例文本，已返回上次阅读句。');
  $('.sentence.current')?.scrollIntoView({block:'center',behavior:'smooth'});
 }
}
function checkSettings() {
 const field=$('#base'),error=$('#settings-error');
 if(!field||!error)return false;
 const base=field.value.trim();let valid=false;
 try { const parsed=new URL(base);valid=parsed.protocol==='https:'&&!parsed.username&&!parsed.password; } catch(_){}
 error.hidden=valid;error.textContent=valid?'':'请输入完整的 HTTPS 服务地址，例如 https://api.example.com/v1';
 if(!valid){const result=$('#settings-result');if(result)result.textContent='';field.focus();}return valid;
}
function generation(id) {
 const ep=episodes.find(e=>e.id===id)||getEpisode();
 $('#dialog-title').textContent='生成前，先确认处理范围';
 $('#dialog-copy').textContent=`${ep.title} · ${ep.duration/60} 分钟。真实产品会依次转写、翻译和生成总结，执行前需按实际内容估算处理量与费用。本原型未连接服务，不提交任务或扣费。`;
 $('#dialog-actions').innerHTML=button('知道了','close-dialog')+button('查看模型设置','configure','primary');
 $('#info-dialog').showModal();
}
let sleepDeadline=0;
document.addEventListener('click',event=>{
 const el=event.target.closest('button[data-action],button[data-page],[role=button][data-action]');if(!el)return;
 if(el.dataset.page){navigate(el.dataset.page,{show:el.dataset.show,filter:el.dataset.filter});return;}
 const action=el.dataset.action;
 switch(action){
 case 'menu': {const open=$('#app').classList.toggle('menu-open');el.setAttribute('aria-expanded',String(open));el.setAttribute('aria-label',open?'关闭导航':'打开导航');break;}
 case 'theme':state.dark=!state.dark;render();break;
 case 'discover':navigate('discover');break;
 case 'all-episodes':navigate('episodes');break;
 case 'show':navigate('episodes',{show:el.dataset.show});break;
 case 'open':openEpisode(el.dataset.id);break;
 case 'open-current':navigate('transcript');break;
 case 'toggle':toggle();break;
 case 'play-episode':if(state.episode===el.dataset.id){toggle();}else{state.episode=el.dataset.id;state.playing=true;render();notify('已切换单集，进度为演示，不播放真实音频。');}break;
 case 'restart':seek(0);state.playing=true;render();notify('已从头开始演示，不播放真实音频。');break;
 case 'back':seek(position()-15);break;
 case 'forward':seek(position()+30);break;
 case 'sentence':state.reading=Number(el.dataset.sec);seek(state.reading);render();$('.sentence.current')?.focus({preventScroll:true});break;
 case 'anchor':state.reading=Number(el.dataset.sec);seek(state.reading);state.playing=true;currentSentence();notify('已定位到原句，演示重听进度。');break;
 case 'current':currentSentence();break;
 case 'language':state.language=el.dataset.language;render();break;
 case 'follow':state.follow=!state.follow;render();break;
 case 'focus':state.focus=!state.focus;render();break;
 case 'filter':state.filter=el.dataset.filter;render();break;
 case 'subscribe':{const id=el.dataset.show;if(state.subscriptions.includes(id)){state.subscriptions=state.subscriptions.filter(x=>x!==id);notify('已取消示例订阅。');}else{state.subscriptions.push(id);notify('已添加到我的节目。');}render();break;}
 case 'cancel-job':state.job='canceled';render();notify('演示转写任务已取消，播放控制仍可使用。');break;
 case 'generate':generation(el.dataset.id);break;
 case 'mark-heard':state.heard=[...new Set([...state.heard,...episodes.filter(e=>(!state.show||e.show===state.show)&&(state.filter!=='downloaded'||e.downloaded)).map(e=>e.id)])];render();notify('当前列表已标为已听。');break;
 case 'reveal':{const input=$('#demo-key');input.type=input.type==='password'?'text':'password';el.textContent=input.type==='password'?'显示':'隐藏';break;}
 case 'check-format':if(checkSettings())$('#settings-result').textContent='地址格式正确。未测试网络连接，也未验证模型可用性。';break;
 case 'save-settings':if(checkSettings()){state.prefs={base:$('#base').value.trim(),chat:$('#chat-model').value.trim(),asr:$('#asr-model').value.trim(),refresh:$('#refresh').value,auto:$('#auto-update').checked};persist();$('#settings-result').textContent=memoryOnly?'偏好已暂存在当前页面，当前预览不允许本地存储。':'非敏感偏好已保存到浏览器本地，密钥未保存。';$('#demo-key').value='';}break;
 case 'close-dialog':$('#info-dialog').close();break;
 case 'configure':$('#info-dialog').close();navigate('settings');break;
 }
});
document.addEventListener('input',event=>{
 if(event.target.id==='seek')seek(Number(event.target.value));
 if(event.target.id==='base'){const result=$('#settings-result');if(result)result.textContent='';}
 if(event.target.id==='search'){state.query=event.target.value;const q=state.query.toLowerCase().trim();$('#search-results').innerHTML=discoverResults(shows.filter(s=>`${s.name} ${s.category} ${s.description}`.toLowerCase().includes(q)));}
});
document.addEventListener('change',event=>{
 const el=event.target;
 if(el.id==='rate'){state.rate=Number(el.value);persist();}
 if(el.id==='sleep'){state.sleep=Number(el.value);sleepDeadline=state.sleep?Date.now()+state.sleep*60000:0;notify(state.sleep?`${state.sleep} 分钟后停止演示进度。`:'已关闭定时。');}
 if(el.id==='theme-choice'){state.dark=el.value==='dark';document.documentElement.classList.toggle('dark',state.dark);persist();}
 if(el.id==='auto-follow'){state.follow=el.checked;persist();}
});
document.addEventListener('focusout',event=>{if(event.target.id==='base')checkSettings();});
document.addEventListener('keydown',event=>{
 if(event.target.matches('input,textarea,select,[contenteditable=true]')||$('#info-dialog').open)return;
 if(event.code==='Space'&&event.target===document.body){event.preventDefault();toggle();}
 if((event.ctrlKey||event.metaKey)&&['ArrowLeft','ArrowRight'].includes(event.key)){event.preventDefault();seek(position()+(event.key==='ArrowLeft'?-15:30));}
 if(event.key.toLowerCase()==='f'&&['transcript','summary'].includes(state.page)){state.focus=!state.focus;render();}
 if((event.key==='Enter'||event.code==='Space')&&event.target.matches('.sentence')){event.preventDefault();event.target.click();}
 if(event.key==='/'&&state.page==='discover'){event.preventDefault();$('#search')?.focus();}
});
setInterval(()=>{
 if(sleepDeadline&&Date.now()>=sleepDeadline){sleepDeadline=0;state.sleep=0;state.playing=false;render();notify('定时结束，演示进度已暂停。');}
 if(!state.playing)return;
 seek(position()+state.rate);
 if(position()>=getEpisode().duration){state.playing=false;render();}
},1000);
window.addEventListener('pagehide',persist);
render();
})();
