(() => {
    'use strict';
    const groups = [
        {id:'unit', title:'Unit Testing', tool:'NUnit · Kiểm thử logic và các giá trị biên', suites:['unit']},
        {id:'api', title:'API Testing', tool:'Playwright API / Newman · HTTP contract', suites:['api','newman']},
        {id:'web', title:'Web E2E Testing', tool:'Playwright · Thao tác trên trình duyệt thật', suites:['web-e2e']},
        {id:'mobile', title:'Mobile Testing', tool:'Appium · Android emulator / UiAutomator2', suites:['mobile']},
        {id:'performance', title:'Performance Testing', tool:'k6 · Characterization, load và stress', suites:['performance-characterization','performance-load','performance-stress']},
        {id:'visual', title:'Visual Regression', tool:'Playwright · So sánh ảnh với baseline đã duyệt', suites:['visual']},
        {id:'ai', title:'AI-assisted Testing', tool:'NUnit · Các test case đã được review', suites:['ai-assisted']},
        {id:'ci', title:'CI/CD', tool:'GitHub Actions · Workflow và artifacts từ CI', suites:[]},
        {id:'http', title:'HTTP Integration', tool:'Bổ sung · Razor Pages / CSRF / HTTP', suites:['http-integration']}
    ];
    const $ = id => document.getElementById(id);
    const node = (tag, text, className) => { const element=document.createElement(tag); if(text!=null)element.textContent=text; if(className)element.className=className; return element; };
    const statusClass = status => status==='ENVIRONMENT BLOCKED'?'BLOCKED':status;
    const badge = status => node('span',status||'CHƯA CHẠY',`badge ${statusClass(status||'')}`);
    const stamp = value => value ? new Date(value).toLocaleString('vi-VN') : '—';
    const elapsed = run => { const ms=Date.parse(run.finishedAtUtc||new Date())-Date.parse(run.startedAtUtc);return Number.isFinite(ms)?`${Math.max(0,ms/1000).toFixed(1)}s`:'—'; };
    const counts = run => run.total==null?'—':`${run.passed??0} / ${(run.failed??0)+(run.errors??0)} / ${run.skipped??0}`;
    const shortSuite = suite => ({api:'Playwright API',newman:'Newman','performance-characterization':'Characterization','performance-load':'Load','performance-stress':'Stress'}[suite]||suite);
    let allRuns=[], selected='all', activeRun=null, loading=false;
    const query = (handler, run, file) => {
        const parameters=new URLSearchParams({handler});
        if(run){parameters.set('session',run.session);parameters.set('run',run.run);}
        if(file)parameters.set('file',file);
        return `/TestDashboard?${parameters}`;
    };
    const reportButton = run => { const button=node('button','Xem báo cáo ↗','report-button');button.type='button';button.addEventListener('click',()=>openDetail(run));return button; };
    function render() {
        const latest=new Map();
        for(const run of allRuns) if(!latest.has(run.name))latest.set(run.name,run);
        const current=[...latest.values()];
        $('running').textContent=allRuns.filter(r=>r.status==='RUNNING').length;
        $('passed').textContent=current.reduce((sum,r)=>sum+(r.passed||0),0);
        $('failed').textContent=current.reduce((sum,r)=>sum+(r.failed||0)+(r.errors||0),0);
        $('executed').textContent=current.filter(r=>r.status!=='RUNNING'&&r.status!=='NOT EXECUTED'&&r.status!=='ENVIRONMENT BLOCKED'&&r.status!=='INTERRUPTED').length;
        const shown=selected==='all'?groups:groups.filter(g=>g.id===selected);
        $('cards').replaceChildren();
        for(const group of shown){
            const card=node('article',null,'card');
            const records=group.suites.map(s=>latest.get(s)).filter(Boolean);
            const status=['RUNNING','FAILED','ENVIRONMENT BLOCKED','INTERRUPTED','NOT EXECUTED','SKIPPED','PASSED'].find(s=>records.some(r=>r.status===s));
            const top=node('div',null,'card-top');top.append(node('span',String(groups.indexOf(group)+1).padStart(2,'0'),'number'),badge(group.id==='ci'?'GITHUB':status));
            card.append(top,node('h3',group.title),node('p',group.tool));
            if(group.id==='ci'){
                const link=node('a','Mở GitHub Actions ↗');link.href='https://github.com/TruongGiangNgtr/SWT301/actions';link.target='_blank';link.rel='noopener';
                card.append(node('p','Trạng thái CI xem từ workflow thật trên GitHub.'),link);
            }else if(!records.length){card.append(node('div','Chọn topic trong console để bắt đầu.','suite-line'));}
            else for(const run of records){
                const line=node('div',null,'suite-line');const info=node('div',shortSuite(run.name));
                let detail=run.total==null?run.status:`${run.passed??0}/${run.total} pass · ${(run.failed??0)+(run.errors??0)} fail · ${run.skipped??0} skip`;
                if(run.name==='newman'&&run.metrics)detail=`${run.metrics.requests?.total??0} requests · ${run.metrics.assertions?.total??0} assertions`;
                if(run.name.startsWith('performance-')&&run.metrics)detail=`${(run.metrics.httpRequests?.count??0).toLocaleString('vi-VN')} HTTP requests · p95 ${run.metrics.checkLatencyMs?.['p(95)']??'—'} ms`;
                info.append(node('small',detail));line.append(info,reportButton(run));card.append(line);
            }
            $('cards').append(card);
        }
        const allowed=new Set(shown.flatMap(g=>g.suites));
        const history=allRuns.filter(r=>selected==='all'||allowed.has(r.name)).slice(0,40);
        $('history-count').textContent=`${history.length} lần gần nhất`;
        $('history').replaceChildren();
        for(const run of history){
            const row=node('tr');const state=node('td');state.append(badge(run.status));const action=node('td');action.append(reportButton(run));
            row.append(node('td',shortSuite(run.name)),state,node('td',counts(run)),node('td',stamp(run.startedAtUtc)),node('td',elapsed(run)),action);$('history').append(row);
        }
        if(!history.length){const row=node('tr');const cell=node('td','Chưa có lần chạy nào. Kết quả sẽ xuất hiện khi bạn chọn test trong console.','empty');cell.colSpan=6;row.append(cell);$('history').append(row);}
        document.querySelectorAll('nav button').forEach(button=>button.classList.toggle('active',button.dataset.topic===selected));
        $('section-title').textContent=selected==='all'?'Các loại kiểm thử':shown[0].title;
    }
    async function loadDetail() {
        if(!activeRun||!$('detail').open)return;
        const run=activeRun;
        const response=await fetch(query('Detail',run),{cache:'no-store'});
        if(!response.ok)throw new Error(`Báo cáo chưa đọc được (${response.status}).`);
        const data=await response.json();
        if(activeRun!==run)return;
        const nearBottom=$('log').scrollHeight-$('log').scrollTop-$('log').clientHeight<60;
        $('log').textContent=data.log;
        if(nearBottom)$('log').scrollTop=$('log').scrollHeight;
        $('case-table').replaceChildren();
        if(data.cases.length){
            const table=node('table');const head=node('tr');['TEST CASE','OUTCOME','DURATION'].forEach(text=>head.append(node('th',text)));table.append(head);
            for(const test of data.cases){const row=node('tr');const name=node('td',test.name);if(test.message)name.append(node('p',test.message,'case-message'));row.append(name,node('td',test.outcome),node('td',test.duration));table.append(row);}
            $('case-table').append(node('h3',`${data.cases.length} test cases`),table);
        }
        $('artifacts').replaceChildren();
        for(const file of data.files){
            const link=node('a',`${file.name} · ${(file.size/1024).toFixed(1)} KB`,'artifact');link.href=query('Artifact',run,file.name);link.target='_blank';link.rel='noopener';$('artifacts').append(link);
            if(file.name.endsWith('.png')&&/(actual|diff)\.png$/.test(file.name)){const image=node('img');image.src=link.href;image.alt=file.name;image.className='artifact-image';image.loading='lazy';$('artifacts').append(image);}
        }
    }
    async function openDetail(run){
        activeRun=run;$('detail-title').textContent=`${shortSuite(run.name)} · ${run.status}`;
        $('detail-message').textContent=run.message||`Bắt đầu: ${stamp(run.startedAtUtc)} · Thời gian: ${elapsed(run)}`;
        $('detail-metrics').textContent=run.metrics?JSON.stringify(run.metrics,null,2):`Pass / Fail / Skip: ${counts(run)}`;
        $('log').textContent='Đang đọc log…';$('case-table').replaceChildren();$('artifacts').replaceChildren();
        if(!$('detail').open)$('detail').showModal();
        try{await loadDetail();}catch(error){$('log').textContent=error.message;}
    }
    async function refresh(){
        if(loading)return;loading=true;
        try{
            const response=await fetch(query('Data'),{cache:'no-store'});if(!response.ok)throw new Error(`HTTP ${response.status}`);
            const data=await response.json();allRuns=data.runs.sort((a,b)=>Date.parse(b.startedAtUtc)-Date.parse(a.startedAtUtc));render();
            $('connection').textContent='● Đang kết nối';$('connection').style.color='';
            $('updated').textContent=`Cập nhật ${stamp(data.updatedAtUtc)} · Tối đa 50 session gần nhất`;
            $('notice').hidden=!data.unreadable;$('notice').textContent=`${data.unreadable} báo cáo chưa đọc được; đang giữ nguyên trạng thái chưa xác định.`;
            if(activeRun){const updated=allRuns.find(r=>r.session===activeRun.session&&r.run===activeRun.run);if(updated){activeRun=updated;$('detail-title').textContent=`${shortSuite(updated.name)} · ${updated.status}`;$('detail-message').textContent=updated.message||`Bắt đầu: ${stamp(updated.startedAtUtc)} · Thời gian: ${elapsed(updated)}`;}}
            await loadDetail();
        }catch(error){$('connection').textContent='● Mất kết nối';$('connection').style.color='#b45d2d';$('notice').hidden=false;$('notice').textContent=`Không đọc được dữ liệu mới (${error.message}). Giữ runner đang mở; thông tin bên dưới có thể đã cũ.`;}
        finally{loading=false;}
    }
    for(const group of [{id:'all',title:'Tổng quan'},...groups]){const button=node('button',group.title);button.type='button';button.dataset.topic=group.id;button.addEventListener('click',()=>{selected=group.id;render();});$('topics').append(button);}
    $('refresh').addEventListener('click',refresh);$('close-detail').addEventListener('click',()=>{$('detail').close();activeRun=null;});$('detail').addEventListener('close',()=>{activeRun=null;});
    render();refresh();setInterval(refresh,2000);
})();
