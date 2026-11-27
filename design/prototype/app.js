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
 // Theme glyphs follow the family outline set; the icon shows the theme you are in.
 moon:'<path d="M20 15.2A8.2 8.2 0 0 1 8.8 4a8.4 8.4 0 1 0 11.2 11.2Z"/>',
 search:'<circle cx="10" cy="10" r="7"/><path d="m15 15 6 6"/>',
 check:'<path d="m5 12 4 4L20 5"/>',menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
 focus:'<path d="M9 3H3v6m12-6h6v6M3 15v6h6m6 0h6v-6"/>',
 close:'<path d="m5 5 14 14M19 5 5 19"/>',
 sun:'<circle cx="12" cy="12" r="3.5"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>'
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
// Library entries share one page; only the entry matching the active filter is current.
const navButton = (label,page,glyph,attrs='',filter=null) => `<button type="button" class="nav-btn ${state.page===page && !state.show && (filter===null || filter===state.filter)?'active':''}" data-page="${page}" ${attrs}>${icon(glyph)}<span>${label}</span></button>`;
if(document.body.dataset.surface==='mobile'){initMobile();return;}
function sidebar() {
 return `<aside class="sidebar" aria-label="主导航"><button type="button" class="brand" data-page="home" style="border:0;background:none;text-align:left"><span class="brand-mark">${icon('lens')}</span>PodLens</button>
 <nav class="nav-group">${navButton('主页','home','home')}${navButton('发现','discover','compass')}</nav>
 <nav class="nav-group"><div class="nav-title">资料库</div>${navButton('最近更新','episodes','clock','data-filter="all"','all')}${navButton('节目','episodes','grid','data-filter="shows"','shows')}${navButton('已下载','episodes','download','data-filter="downloaded"','downloaded')}</nav>
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
 ${ep.ready?`<div class="reading" data-language="${state.language}"><p class="reading-note">点击一句，定位演示进度。当前仅提供开头 01:09 的示例文本，无真实音频。</p>${sentences.map(([sec,en,zh])=>`<div class="sentence ${sec===state.reading?'current':''}" role="button" tabindex="0" data-action="sentence" data-sec="${sec}" aria-current="${sec===state.reading?'true':'false'}" aria-label="定位到 ${time(sec)} ${escape(zh)}"><span class="stamp">${time(sec)}</span><div><div class="en" lang="en">${en}</div><div class="zh">${zh}</div></div></div>`).join('')}<div class="reading-footer"><span><kbd>Space</kbd> 开始 / 暂停</span><span><kbd>Ctrl / ⌘ ← →</kbd> −15 / +30 秒</span><span><kbd>F</kbd> 专注阅读</span></div></div>`:`<div class="empty"><h2>让这集内容，也能读懂</h2><p>逐句稿尚未生成，播放控制仍可使用。</p>${button('了解生成流程','generate','','data-id="'+ep.id+'"')}</div>`}`;
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
// Topbar theme toggle: the icon is the current theme; name and tooltip name the theme a click switches to.
const themeToggle = () => `<button type="button" class="icon-btn" data-action="theme" aria-label="切换到${state.dark?'浅色':'深色'}模式" title="切换到${state.dark?'浅色':'深色'}模式">${icon(state.dark?'moon':'sun')}</button>`;
function render() {
 const focused=document.activeElement;
 // Only an invoking control inside the app is restored; body also carries data-page and would match a nav button on first render.
 const focusKey=focused?.closest?.('#app') ? JSON.stringify(focused.dataset) : '';
 const focusId=focused?.id;
 const previousScroll=$('.main-scroll')?.scrollTop||0;
 document.documentElement.classList.toggle('dark',state.dark);
 document.title=`PodLens — ${labels[state.page]||'主页'}`;
 $('#app').className=`app${state.focus?' focus-mode':''}`;
 $('#app').innerHTML=`${sidebar()}<div class="workspace"><header class="topbar"><button type="button" class="icon-btn mobile-menu" data-action="menu" aria-label="打开导航" aria-expanded="false">${icon('menu')}</button><span class="breadcrumb">资料库 <span aria-hidden="true">/</span> ${labels[state.page]||'主页'}</span><span class="mode-label">示例内容 · 无真实音频</span>${themeToggle()}</header><main class="main-scroll" id="main"><div class="content">${({home,episodes:listPage,transcript,summary,discover,settings}[state.page]||home)()}</div></main>${player()}</div>`;
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
 if(ep.ready&&p<=77&&state.follow){const current=[...sentences].reverse().find(s=>s[0]<=p)||sentences[0];const changed=state.reading!==current[0];state.reading=current[0];if(changed&&state.page==='transcript')$('.sentence[data-sec=\"'+current[0]+'\"]')?.scrollIntoView({block:'nearest',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});$$('.sentence').forEach(el=>el.classList.toggle('current',Number(el.dataset.sec)===current[0]));}
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
  $('.sentence.current')?.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});
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
 if(el.id==='theme-choice'){state.dark=el.value==='dark';document.documentElement.classList.toggle('dark',state.dark);$('[data-action=theme]').outerHTML=themeToggle();persist();}
 if(el.id==='auto-follow'){state.follow=el.checked;persist();}
});
document.addEventListener('focusout',event=>{if(event.target.id==='base')checkSettings();});
document.addEventListener('keydown',event=>{
 if(event.isComposing||event.repeat||event.target.closest('input,textarea,select,[contenteditable]')||$('#info-dialog').open)return;
 if(event.code==='Space'&&event.target===document.body){event.preventDefault();toggle();}
 if((event.ctrlKey||event.metaKey)&&['ArrowLeft','ArrowRight'].includes(event.key)){event.preventDefault();seek(position()+(event.key==='ArrowLeft'?-15:30));}
 if(event.key.toLowerCase()==='f'&&!event.ctrlKey&&!event.metaKey&&!event.altKey&&['transcript','summary'].includes(state.page)){state.focus=!state.focus;render();}
 if((event.key==='Enter'||event.code==='Space')&&event.target.matches('.sentence')){event.preventDefault();event.target.click();}
 if(event.key==='/'&&!event.ctrlKey&&!event.metaKey&&!event.altKey&&state.page==='discover'){event.preventDefault();$('#search')?.focus();}
});
setInterval(()=>{
 if(sleepDeadline&&Date.now()>=sleepDeadline){sleepDeadline=0;state.sleep=0;state.playing=false;render();notify('定时结束，演示进度已暂停。');}
 if(!state.playing)return;
 seek(position()+state.rate);
 if(position()>=getEpisode().duration){state.playing=false;render();}
},1000);
window.addEventListener('pagehide',persist);
render();
/* Mobile prototype UI. This is a Swift app design contract, not an implementation architecture. */
function initMobile() {
 const entry=document.body.dataset.page||'home';
 const titles={home:'主页','now-playing':'正在播放',episodes:'单集',discover:'发现',transcript:'逐句稿',settings:'设置'};
 const storageKey='podlens-mobile-prototype-v1';
 const fixture=new URLSearchParams(location.search).get('state');
 let saved={},storageAvailable=true;
 try{saved=JSON.parse(localStorage.getItem(storageKey)||'{}')||{};}catch(_){storageAvailable=false;}
 const m={page:entry,tab:['home','discover','episodes','settings'].includes(entry)?entry:'episodes',selected:'interfaces',positions:{interfaces:38},reading:37,language:'bilingual',follow:true,dark:false,rate:1,subscriptions:['td','ds','mc','lg'],job:'processing',query:'',filter:'all',show:null,section:'transcript',draft:{base:'https://api.openai.com/v1',chat:'gpt-4o-mini'},...saved,playing:false};
 m.page=entry;m.positions={interfaces:38,...saved.positions};m.draft={base:'https://api.openai.com/v1',chat:'gpt-4o-mini',...saved.draft};
 m.subscriptions=Array.isArray(m.subscriptions)?m.subscriptions.filter(id=>shows.some(s=>s.id===id)):['td','ds','mc','lg'];
 if(!episodes.some(e=>e.id===m.selected))m.selected=null;
 if(fixture==='empty-player')m.selected=null;
 if(fixture==='empty-subscriptions'){m.subscriptions=[];m.selected=null;}
 if(fixture==='processing'){m.selected='sky';m.job='processing';}
 if(fixture==='error'){m.selected='sky';m.job='failed';}
 if(new URLSearchParams(location.search).get('section')==='summary'){m.selected='interfaces';m.section='summary';}
 const history=[],scrolls={};
 let returnFocus=null,feedbackTimer;
 const ep=()=>episodes.find(e=>e.id===m.selected)||null;
 const pos=()=>ep()?Number(m.positions[m.selected]||0):0;
 const btn=(label,action,cls='',attrs='')=>`<button type="button" class="m-button ${cls}" data-mobile-action="${action}" ${attrs}>${label}</button>`;
 const go=(label,page,cls='',attrs='')=>`<button type="button" class="m-button ${cls}" data-mobile-page="${page}" ${attrs}>${label}</button>`;
 // Header theme toggle: the icon is the current theme; name and tooltip name the target theme.
 const themeBtn=()=>btn(icon(m.dark?'moon':'sun'),'theme','m-icon',`aria-label="切换到${m.dark?'浅色':'深色'}主题" title="切换到${m.dark?'浅色':'深色'}主题"`);
 const art=(show,cls='')=>`<div class="m-art ${cls}" role="img" aria-label="${escape(getShow(show).name)} 排版式示例封面">${cover(show)}</div>`;
 const save=()=>{
  if(fixture)return;
  const {page,playing,tab,...data}=m;
  try{localStorage.setItem(storageKey,JSON.stringify(data));}catch(_){storageAvailable=false;}
 };
 const toast=text=>{const el=$('#feedback');el.textContent=text;el.hidden=false;clearTimeout(feedbackTimer);feedbackTimer=setTimeout(()=>{el.hidden=true;},4000);};
 function dialog(title,text,actions=''){
  const d=$('#info-dialog');returnFocus=document.activeElement;
  $('#dialog-title').textContent=title;$('#dialog-copy').textContent=text;
  $('#dialog-actions').innerHTML=actions+btn('关闭','close-dialog');
  if(!d.open)d.showModal();
 }
 $('#info-dialog').addEventListener('close',()=>{if(returnFocus?.isConnected)returnFocus.focus({preventScroll:true});else $('.m-heading')?.focus({preventScroll:true});returnFocus=null;});
 function status(e){
  if(e.id==='sky')return m.job==='processing'?'转写中 · 示例 46%':m.job==='failed'?'转写失败 · 示例':'已取消转写';
  return e.ready?'双语稿已就绪':e.downloaded?'已下载 · 尚无逐句稿':'尚无逐句稿';
 }
 function rowMobile(e){
  return `<article class="m-episode">${art(e.show,'m-art-small')}<div class="m-fill"><button type="button" class="m-episode-title" data-mobile-action="open-episode" data-id="${e.id}">${escape(e.title)}</button><p class="m-meta">${getShow(e.show).name} · ${e.duration/60} 分钟</p><p class="m-status ${e.id==='sky'&&m.job==='failed'?'m-error':''}">${status(e)}</p></div>${btn(icon(m.selected===e.id&&m.playing?'pause':'play'),'play-episode','m-icon',`data-id="${e.id}" aria-label="${m.selected===e.id&&m.playing?'暂停':'播放'} ${escape(e.title)}"`)}</article>`;
 }
 function noPlayback(){return `<section class="m-empty"><h2>还没有正在播放的单集</h2><p>从单集里选一集开始，随时回到文字继续读。</p>${go('选择单集','episodes','m-primary')}</section>`;}
 function homeMobile(){
  const e=ep();const list=episodes.filter(e=>m.subscriptions.includes(e.show)&&e.id!==m.selected).slice(0,3);
  return `<h1 class="m-heading" tabindex="-1">主页</h1>${e?`<section class="m-current"><p class="m-eyebrow">继续收听</p><div class="m-current-top">${art(e.show,'m-art-medium')}<div class="m-fill"><h2>${escape(e.title)}</h2><p class="m-meta">${getShow(e.show).name}</p></div></div><div class="m-progress-label"><span data-mobile-time>${time(pos())}</span><span>${time(e.duration)}</span></div><progress max="${e.duration}" value="${pos()}" data-mobile-progress aria-label="当前单集收听进度"></progress><div class="m-current-actions">${btn(`${icon(m.playing?'pause':'play')} ${m.playing?'暂停':'继续收听'}`,'toggle','m-primary')}${btn('继续阅读','current','m-quiet')}</div>${e.ready?`<p class="m-reading-memory">上次读到 ${time(m.reading)}</p>`:''}</section>`:noPlayback()}
  <section class="m-section"><div class="m-section-title"><h2>最近更新</h2>${go('查看全部','episodes','m-quiet')}</div>${list.length?list.map(rowMobile).join(''):`<div class="m-empty m-compact"><h3>订阅后，新内容会出现在这里</h3><p>先到发现页选择一档节目。</p>${go('发现播客','discover','m-quiet')}</div>`}</section>`;
 }
 function fullPlayer(){
  const e=ep();if(!e)return `<h1 class="m-heading" tabindex="-1">正在播放</h1>${noPlayback()}`;
  return `<h1 class="m-heading m-player-heading" tabindex="-1">正在播放</h1><section class="m-full-player">${art(e.show,'m-art-large')}<div class="m-player-description"><p class="m-eyebrow">${getShow(e.show).name}</p><h2>${escape(e.title)}</h2><p class="m-meta">${m.playing?'演示播放中':'已暂停'} · 无真实音频</p></div><label class="sr-only" for="mobile-seek">播放位置</label><input id="mobile-seek" type="range" min="0" max="${e.duration}" value="${pos()}" aria-valuetext="${time(pos())}"><div class="m-progress-label"><span data-mobile-time>${time(pos())}</span><span data-mobile-remaining>−${time(e.duration-pos())}</span></div><div class="m-transport">${btn(`${icon('replay')}<span>15 秒</span>`,'back','m-seek-button','aria-label="快退15秒"')}${btn(icon(m.playing?'pause':'play'),'toggle','m-primary m-big-play',`aria-label="${m.playing?'暂停':'播放'}"`)}${btn(`${icon('replay')}<span>15 秒</span>`,'forward','m-seek-button m-forward','aria-label="快进15秒"')}</div><div class="m-player-links">${btn(`${icon('book')} 当前句`,'current','m-quiet')}${btn('结束播放','stop','m-quiet')}</div></section>`;
 }
 function episodesMobile(){
  const list=episodes.filter(e=>(m.show?e.show===m.show:m.subscriptions.includes(e.show))&&(m.filter!=='downloaded'||e.downloaded));
  return `<h1 class="m-heading" tabindex="-1">${m.show?escape(getShow(m.show).name):'单集'}</h1><div class="m-filter" aria-label="单集筛选">${[['all','全部'],['downloaded','已下载']].map(([id,t])=>btn(t,'filter',m.filter===id?'m-selected':'',`data-filter="${id}" aria-pressed="${m.filter===id}"`)).join('')}</div>${m.show?btn('查看全部订阅','clear-show','m-quiet'):''}${list.length?list.map(rowMobile).join(''):`<section class="m-empty"><h2>${m.filter==='downloaded'?'这里还没有下载内容':'还没有订阅节目'}</h2><p>${m.filter==='downloaded'?'切换到全部，查看已有单集示例。':'到发现页添加节目，再选择想听的一集。'}</p>${m.filter==='downloaded'?btn('查看全部','clear-filter','m-quiet'):go('发现播客','discover','m-primary')}</section>`}`;
 }
 function discoverCards(){
  const q=m.query.trim().toLowerCase();const list=shows.filter(s=>`${s.name} ${s.category} ${s.description}`.toLowerCase().includes(q));
  return list.length?list.map(s=>`<article class="m-discover-card"><div class="m-discover-title">${art(s.id,'m-art-medium')}<div class="m-fill"><h2>${s.name}</h2><p class="m-meta">${s.category}</p></div></div><p>${s.description}</p><div class="m-discover-actions">${btn(m.subscriptions.includes(s.id)?`${icon('check')} 已订阅`:`${icon('plus')} 添加订阅`,'subscribe','',`data-id="${s.id}" aria-pressed="${m.subscriptions.includes(s.id)}"`)}${btn('查看单集','show','m-quiet',`data-id="${s.id}"`)}</div></article>`).join(''):`<div class="m-empty"><h2>没有匹配的节目</h2><p>试试“设计”或“科学”，也可以清空搜索。</p>${btn('清空搜索','clear-search','m-quiet')}</div>`;
 }
 function discoverMobile(){
  return `<h1 class="m-heading" tabindex="-1">发现</h1><p class="m-meta">${m.subscriptions.length?`已订阅 ${m.subscriptions.length} 档节目`:'还没有订阅，先挑一档喜欢的。'}</p><label class="m-search" for="mobile-search">${icon('search')}<input id="mobile-search" type="search" aria-label="搜索示例节目" placeholder="搜索示例节目" value="${escape(m.query)}"></label><p class="m-caption">仅搜索本地示例节目，不连接播客目录。</p><div id="mobile-results">${discoverCards()}</div>`;
 }
 function missingTranscript(e){
  const working=e?.id==='sky'&&m.job==='processing',failed=e?.id==='sky'&&m.job==='failed';
  if(working)return `<section class="m-empty m-processing"><h2>逐句稿正在转写</h2><p>示例任务 · 46%。播放与转写互不阻塞。</p><progress value="46" max="100" aria-label="示例转写进度46%"></progress>${btn('取消转写','cancel-job','m-quiet')}</section>`;
  if(failed)return `<section class="m-empty"><h2>转写未完成</h2><p class="m-error" role="status">转写失败（示例）。已保留原单集，可以继续播放。</p>${btn('查看重试说明','retry-job','m-primary')}${go('检查服务设置','settings','m-quiet')}</section>`;
  return `<section class="m-empty"><h2>${e?'这集还没有逐句稿':'先选择一集开始阅读'}</h2><p>${e?.id==='sky'?'转写已取消，已有内容和播放位置保留。':'此处只提供已就绪的示例文本，不会把其他单集的稿件放到这里。'}</p>${e?btn('了解生成流程','generate','m-quiet'):go('选择单集','episodes','m-primary')}</section>`;
 }
 function summaryMobile(){
  return `<div class="m-summary"><p class="m-caption">示例内容提要 · 时间锚点返回原句</p><section><h2>一句话总结</h2><p class="m-summary-body">好的界面靠做减法赢得注意力，让排版、默认值与清晰的引导，安静地托住内容。</p></section><section><h2>值得带走的要点</h2>${[[6,'每多一个控件，就多索取一次注意力。'],[29,'逐句稿是阅读界面，行高与栏宽应当服务于阅读。'],[53,'每一个默认值，都应该有清楚的理由。']].map(([sec,text])=>`<div class="m-summary-point"><p>${text}</p>${btn(`${time(sec)} · 查看原句`,'anchor','m-quiet',`data-sec="${sec}"`)}</div>`).join('')}</section><section><h2>值得重听的话</h2><blockquote><p lang="en">“Defaults are the most honest part of a product.”</p><p class="m-caption">默认状态是一个产品最诚实的部分。</p>${btn(`${icon('play')} 从 00:53 重听`,'anchor','m-quiet','data-sec="53"')}</blockquote></section></div>`;
 }
 function transcriptMobile(){
  const e=ep();
  return `<h1 class="m-heading m-detail-title" tabindex="-1">${e?escape(e.title):'逐句稿'}</h1>${e?`<p class="m-meta">${getShow(e.show).name}</p>`:''}<nav class="m-reading-tabs" aria-label="单集内容">${[['transcript','逐句稿'],['summary','总结']].map(([id,t])=>btn(t,'section',m.section===id?'m-current-tab':'',`data-section="${id}" aria-pressed="${m.section===id}"`)).join('')}</nav>${!e?.ready?missingTranscript(e):m.section==='summary'?summaryMobile():`<div class="m-reading-controls"><label for="mobile-language" class="sr-only">阅读语言</label><select id="mobile-language" aria-label="阅读语言">${[['bilingual','双语'],['original','原文'],['translation','译文']].map(([id,t])=>`<option value="${id}" ${m.language===id?'selected':''}>${t}</option>`).join('')}</select>${btn('当前句','current','m-quiet')}</div><div class="m-transcript" data-language="${m.language}">${sentences.map(([sec,en,zh])=>`<div class="m-sentence ${sec===m.reading?'is-current':''}" role="button" tabindex="0" data-mobile-action="sentence" data-sec="${sec}" aria-current="${sec===m.reading?'true':'false'}" aria-label="定位至 ${time(sec)}：${escape(zh)}"><div class="m-sentence-meta"><span>${time(sec)}</span><span class="m-current-marker" aria-hidden="true">当前</span></div><p class="m-en" lang="en">${en}</p><p class="m-zh" lang="zh-CN">${zh}</p></div>`).join('')}</div><p class="m-caption m-transcript-note">点击句子仅定位演示进度，无真实音频。示例文本截至 01:09。</p>`}`;
 }
 function settingsMobile(){
  return `<h1 class="m-heading" tabindex="-1">设置</h1><section class="m-settings-section"><h2>阅读与播放</h2><div class="m-setting"><label for="mobile-theme">外观</label><select id="mobile-theme"><option value="light" ${!m.dark?'selected':''}>浅色</option><option value="dark" ${m.dark?'selected':''}>深色</option></select></div><div class="m-setting"><label class="m-toggle-label" for="mobile-follow"><span>跟随当前句</span><input id="mobile-follow" type="checkbox" ${m.follow?'checked':''}></label></div><div class="m-setting"><label for="mobile-rate">播放倍速</label><select id="mobile-rate">${[1,1.25,1.5,2,2.5,3].map(v=>`<option value="${v}" ${m.rate===v?'selected':''}>${v}×</option>`).join('')}</select></div></section><section class="m-settings-section"><h2>模型服务</h2><p class="m-caption">原型未连接服务，不产生费用。请勿输入真实密钥。</p><div class="m-form-field"><label for="mobile-base">服务地址</label><input id="mobile-base" type="url" value="${escape(m.draft.base)}" autocomplete="off" spellcheck="false" aria-describedby="mobile-base-error"><p id="mobile-base-error" class="m-error" hidden role="alert"></p></div><div class="m-form-field"><label for="mobile-model">聊天模型</label><input id="mobile-model" value="${escape(m.draft.chat)}" autocomplete="off"></div><p class="m-caption">未连接 · 未保存密钥</p>${btn('保存非敏感偏好','save-settings','m-primary')}<p id="mobile-save-result" class="m-caption" role="status"></p></section><section class="m-settings-section"><h2>资料库</h2><p class="m-meta">${m.subscriptions.length} 档示例订阅 · ${episodes.length} 集示例内容</p>${go('管理订阅','discover','m-quiet')}${m.selected?btn('结束当前播放','stop','m-quiet'):''}</section><p class="m-caption">${storageAvailable?'阅读位置和非敏感偏好保存在浏览器本地。预览限制存储时，仅在当前页面保留。':'当前预览不允许本地存储，状态仅在当前页面保留。'}<br>这是原生 iOS 应用的交互设计示意，无真实音频与 API 调用。</p>`;
 }
 function miniPlayer(){
  const e=ep();if(!e||m.page==='now-playing')return '';
  return `<div class="m-mini-player"><button type="button" class="m-mini-open" data-mobile-page="now-playing" aria-label="打开正在播放：${escape(e.title)}">${art(e.show,'m-art-mini')}<span class="m-fill"><span class="m-mini-title">${escape(e.title)}</span><span class="m-mini-state">${m.playing?'演示播放中':'已暂停'} · ${getShow(e.show).name}</span></span></button>${btn(icon(m.playing?'pause':'play'),'toggle','m-icon',`aria-label="${m.playing?'暂停':'播放'}"`)}</div>`;
 }
 function tabbar(){return `<nav class="m-tabs" aria-label="主导航">${[['home','主页','home'],['discover','发现','compass'],['episodes','单集','grid'],['settings','设置','settings']].map(([id,t,glyph])=>`<button type="button" data-mobile-tab="${id}" class="m-tab ${m.tab===id?'is-active':''}" ${m.tab===id?'aria-current="page"':''}>${icon(glyph)}<span>${t}</span></button>`).join('')}</nav>`;}
 function renderMobile(){
  const previous=$('.m-main')?.scrollTop||0;
  const focused=document.activeElement,focusId=focused?.id,key=focused?.dataset?JSON.stringify(focused.dataset):'';
  document.documentElement.classList.toggle('dark',m.dark);
  document.title=`PodLens — ${titles[m.page]||'主页'} · iPhone`;
  const detail=['transcript','now-playing'].includes(m.page);
  $('#app').className='mobile-app';
  $('#app').innerHTML=`<header class="m-header">${detail?btn(`${icon('arrow')}<span>返回</span>`,'back-page','m-back'):'<span class="m-brand">PodLens</span>'}<span class="m-header-space"></span><span class="m-demo-label">交互示例</span>${themeBtn()}</header><main class="m-main" id="main"><div class="m-content">${({home:homeMobile,'now-playing':fullPlayer,episodes:episodesMobile,discover:discoverMobile,transcript:transcriptMobile,settings:settingsMobile}[m.page]||homeMobile)()}</div></main><footer class="m-bottom">${miniPlayer()}${tabbar()}</footer>`;
  $('.m-main').scrollTop=previous;
  if(focusId&&document.getElementById(focusId))document.getElementById(focusId).focus({preventScroll:true});
  else if(key&&key!=='{}')$$('[data-mobile-action],[data-mobile-page],[data-mobile-tab]').find(el=>JSON.stringify(el.dataset)===key)?.focus({preventScroll:true});
  save();
 }
 function navigateMobile(page,{back=false,tab=false}={}){
  scrolls[m.page]=$('.m-main')?.scrollTop||0;
  if(!back&&!tab&&page!==m.page)history.push({page:m.page,tab:m.tab});
  if(tab){history.length=0;m.tab=page;}
  m.page=page;renderMobile();$('.m-main').scrollTop=scrolls[page]||0;
  $('.m-heading')?.focus({preventScroll:true});
 }
 function selectEpisode(id){m.selected=id;m.reading=id==='interfaces'?37:0;}
 function seekMobile(value){
  if(!ep())return;
  m.positions[m.selected]=Math.max(0,Math.min(ep().duration,Number(value)));
  if(ep().ready&&m.follow&&pos()<=77){const match=[...sentences].reverse().find(s=>s[0]<=pos())||sentences[0];m.reading=match[0];}
  $$('[data-mobile-time]').forEach(el=>el.textContent=time(pos()));
  $$('[data-mobile-remaining]').forEach(el=>el.textContent='−'+time(ep().duration-pos()));
  $$('[data-mobile-progress]').forEach(el=>el.value=pos());
  const slider=$('#mobile-seek');if(slider){slider.value=pos();slider.setAttribute('aria-valuetext',time(pos()));}
  const before=$('.m-sentence.is-current')?.dataset.sec;
  $('.m-sentence').forEach(el=>{const current=Number(el.dataset.sec)===m.reading;el.classList.toggle('is-current',current);el.setAttribute('aria-current',String(current));});
  if(m.follow&&m.playing&&before!==String(m.reading))$('.m-sentence.is-current')?.scrollIntoView({block:'nearest',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});
  save();
 }
 function currentMobile(){
  if(ep()?.ready&&pos()<=77)m.reading=([...sentences].reverse().find(s=>s[0]<=pos())||sentences[0])[0];
  m.section='transcript';navigateMobile('transcript');
  if(pos()>77)toast('当前位置超出示例文本，已返回上次阅读句。');
  $('.m-sentence.is-current')?.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});
 }
 function generationMobile(retry=false){
  dialog(retry?'重试转写':'生成前确认',`${ep()?.title||'所选单集'}。真实产品会先估算处理量和费用，再执行转写、翻译与总结。此原型未连接服务，不提交任务或扣费。`,go('检查服务设置','settings','m-primary'));
 }
 function validateMobile(){
  const input=$('#mobile-base'),error=$('#mobile-base-error');if(!input||!error)return false;
  let valid=false;try{const url=new URL(input.value.trim());valid=url.protocol==='https:'&&!url.username&&!url.password;}catch(_){}
  error.hidden=valid;error.textContent=valid?'':'请输入完整的 HTTPS 服务地址，例如 https://api.example.com/v1';
  input.setAttribute('aria-invalid',String(!valid));if(!valid)input.focus();return valid;
 }
 document.addEventListener('click',event=>{
  const target=event.target.closest('[data-mobile-action],[data-mobile-page],[data-mobile-tab]');if(!target)return;
  if(target.dataset.mobileTab){navigateMobile(target.dataset.mobileTab,{tab:true});return;}
  if(target.dataset.mobilePage){if($('#info-dialog').open)$('#info-dialog').close();navigateMobile(target.dataset.mobilePage);return;}
  switch(target.dataset.mobileAction){
   case 'back-page':{const previous=history.pop();if(previous){m.tab=previous.tab;navigateMobile(previous.page,{back:true});}else navigateMobile(m.tab,{tab:true});break;}
   case 'theme':m.dark=!m.dark;renderMobile();break;
   case 'toggle':if(!ep()){navigateMobile('episodes',{tab:true});break;}m.playing=!m.playing;renderMobile();break;
   case 'play-episode':if(m.selected===target.dataset.id)m.playing=!m.playing;else{selectEpisode(target.dataset.id);m.playing=true;}renderMobile();break;
   case 'open-episode':if(m.selected!==target.dataset.id){selectEpisode(target.dataset.id);m.playing=false;}m.section='transcript';navigateMobile('transcript');break;
   case 'current':currentMobile();break;
   case 'back':seekMobile(pos()-15);break;
   case 'forward':seekMobile(pos()+15);break;
   case 'stop':m.playing=false;m.selected=null;renderMobile();toast('已结束播放，收听位置仍然保留。');break;
   case 'sentence':m.reading=Number(target.dataset.sec);seekMobile(m.reading);renderMobile();$('.m-sentence.is-current')?.focus({preventScroll:true});break;
   case 'anchor':m.reading=Number(target.dataset.sec);m.section='transcript';seekMobile(m.reading);renderMobile();$('.m-sentence.is-current')?.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});toast('已定位到原句，仅演示播放位置。');break;
   case 'section':m.section=target.dataset.section;renderMobile();$('.m-reading-tabs [data-section="'+m.section+'"]')?.focus({preventScroll:true});break;
   case 'filter':m.filter=target.dataset.filter;renderMobile();break;
   case 'clear-filter':m.filter='all';renderMobile();break;
   case 'clear-show':m.show=null;renderMobile();break;
   case 'show':m.show=target.dataset.id;m.filter='all';navigateMobile('episodes');break;
   case 'subscribe':{const id=target.dataset.id;m.subscriptions=m.subscriptions.includes(id)?m.subscriptions.filter(x=>x!==id):[...m.subscriptions,id];renderMobile();toast(m.subscriptions.includes(id)?'已添加到订阅。':'已取消订阅。');break;}
   case 'clear-search':m.query='';renderMobile();$('#mobile-search')?.focus();break;
   case 'cancel-job':m.job='canceled';renderMobile();toast('已取消示例任务，播放不受影响。');break;
   case 'retry-job':generationMobile(true);break;
   case 'generate':generationMobile();break;
   case 'save-settings':if(validateMobile()){save();$('#mobile-save-result').textContent=storageAvailable?'偏好已保存；未测试服务连接，也未保存密钥。':'偏好暂存在当前页面；预览不允许本地存储。';}break;
   case 'close-dialog':$('#info-dialog').close();break;
  }
 });
 document.addEventListener('input',event=>{
  const el=event.target;
  if(el.id==='mobile-seek')seekMobile(el.value);
  if(el.id==='mobile-search'){m.query=el.value;$('#mobile-results').innerHTML=discoverCards();}
  if(el.id==='mobile-base'){m.draft.base=el.value;$('#mobile-save-result').textContent='';}
  if(el.id==='mobile-model'){m.draft.chat=el.value;$('#mobile-save-result').textContent='';}
 });
 document.addEventListener('change',event=>{
  const el=event.target;
  if(el.id==='mobile-theme'){m.dark=el.value==='dark';document.documentElement.classList.toggle('dark',m.dark);$('[data-mobile-action=theme]').outerHTML=themeBtn();save();}
  if(el.id==='mobile-follow'){m.follow=el.checked;save();}
  if(el.id==='mobile-rate'){m.rate=Number(el.value);save();}
  if(el.id==='mobile-language'){m.language=el.value;renderMobile();}
 });
 document.addEventListener('focusout',event=>{if(event.target.id==='mobile-base'&&$('#mobile-base'))validateMobile();});
 document.addEventListener('keydown',event=>{if(event.isComposing||event.repeat)return;if(event.target.matches('.m-sentence')&&(event.key==='Enter'||event.code==='Space')){event.preventDefault();event.target.click();}});
 setInterval(()=>{if(m.playing&&ep()){seekMobile(pos()+m.rate);if(pos()>=ep().duration){m.playing=false;renderMobile();}}},1000);
 window.addEventListener('pagehide',save);
 renderMobile();
}

})();
