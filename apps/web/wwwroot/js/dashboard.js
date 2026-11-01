(() => {
    'use strict';
    const $ = id => document.getElementById(id);
    let active = false, enabled = false, loading = false, renderedResults = '';
    const notice = message => { $('notice').textContent = message; $('notice').hidden = !message; };
    const statusClass = value => value === 'PASSED' ? 'passed' : value === 'RUNNING' || value === 'QUEUED' ? 'running' : value === 'FAILED' ? 'failed' : 'blocked';
    const cell = (row, value) => { const element = document.createElement('td'); element.textContent = value ?? '—'; row.append(element); return element; };
    const label = value => { const badge = document.createElement('span'); badge.className = `status ${statusClass(value)}`; badge.textContent = value; return badge; };
    function artifact(path) {
        const match = path?.replaceAll('\\', '/').match(/\/TestResults\/(.+)$/i);
        return match ? '/dashboard?handler=Artifact&path=' + encodeURIComponent(match[1]) : null;
    }
    function renderResults(runs) {
        const signature = JSON.stringify(runs);
        if (signature === renderedResults) return;
        renderedResults = signature;
        const expanded = new Set([...$('metrics').querySelectorAll('details[open]')].map(detail => detail.dataset.suite));
        $('results').replaceChildren(); $('metrics').replaceChildren();
        if (!runs.length) { const row = document.createElement('tr'); cell(row, 'Chưa có kết quả.').colSpan = 7; $('results').append(row); }
        for (const run of runs) {
            const row = document.createElement('tr');
            cell(row, run.name); cell(row, '').append(label(run.status));
            for (const value of [run.total, run.passed, run.failed == null ? null : `${run.failed} / ${run.errors ?? 0}`, run.skipped]) cell(row, value);
            const reports = cell(row, '');
            for (const path of [run.log, ...(run.reports ?? [])]) {
                const url = artifact(path); if (!url) continue;
                const link = document.createElement('a'); link.href = url; link.target = '_blank'; link.rel = 'noopener'; link.textContent = path.replaceAll('\\', '/').split('/').pop(); reports.append(link);
            }
            $('results').append(row);
            if (run.metrics || run.message) {
                const detail = document.createElement('details'), summary = document.createElement('summary'), content = document.createElement('pre');
                detail.dataset.suite = run.name; detail.open = expanded.has(run.name);
                summary.textContent = `${run.name} · thông tin / số đo`; content.textContent = [run.message, run.metrics ? JSON.stringify(run.metrics, null, 2) : ''].filter(Boolean).join('\n');
                detail.append(summary, content); $('metrics').append(detail);
            }
        }
    }
    async function refresh() {
        if (loading) return; loading = true;
        try {
            const response = await fetch('/dashboard?handler=State', { cache: 'no-store' });
            if (!response.ok) throw new Error(`Không đọc được trạng thái (${response.status}).`);
            const state = await response.json(); active = state.active; enabled = state.enabled;
            document.querySelectorAll('.run, #run-all').forEach(button => button.disabled = active || !enabled);
            if (!enabled) notice('Chạy run-dashboard.cmd ở thư mục repository để bật chức năng thực thi test trên máy này.');
            const latest = new Map();
            const sessions = [...state.history].reverse();
            for (const session of sessions) for (const run of session.runs ?? []) latest.set(run.name, run);
            const current = state.jobs[0];
            if (current) {
                $('run-state').textContent = `${current.suite} · ${current.status}`;
                $('run-time').textContent = current.startedAt ? new Date(current.startedAt).toLocaleTimeString('vi-VN') : '';
                const scroll = $('log').scrollTop;
                $('log').textContent = [current.log, current.error].filter(Boolean).join('\n') || 'Đang chuẩn bị runner…';
                $('log').scrollTop = $('auto-scroll').checked ? $('log').scrollHeight : scroll;
                if (current.results) for (const run of current.results.runs) latest.set(run.name, run);
            }
            const runs = current ? current.results?.runs ?? [] : state.history[0]?.runs ?? [];
            renderResults(runs);
            for (const topic of document.querySelectorAll('[data-suites]')) {
                const suites = topic.dataset.suites.split(',');
                const running = active && current && suites.includes(current.progress?.status === 'RUNNING' ? current.progress.name : current.suite);
                const results = suites.map(name => latest.get(name)).filter(Boolean);
                const completed = current?.results?.runs.filter(run => suites.includes(run.name)) ?? [];
                const queued = active && current?.suite === 'all' && !running && !completed.length;
                const value = running ? 'RUNNING' : queued ? 'QUEUED' : results.length ? results.every(run => run.status === 'PASSED') ? 'PASSED' : results.find(run => run.status !== 'PASSED').status : 'CHƯA CHẠY';
                const badge = topic.querySelector('.status'); badge.textContent = value; badge.className = `status ${statusClass(value)}`;
                badge.title = results.map(run => `${run.name}: ${run.status} · ${new Date(run.startedAtUtc).toLocaleString('vi-VN')}`).join('\n');
            }
            const values = [...latest.values()];
            $('passed-count').textContent = values.length ? `${values.filter(run => run.status === 'PASSED').length} / ${values.length}` : '—';
            $('activity').textContent = active ? 'Đang chạy' : 'Sẵn sàng';
            $('activity-note').textContent = active ? current.suite : 'Có thể bắt đầu lượt test tiếp theo';
            $('run-dot').classList.toggle('busy', active);
            $('run-description').textContent = current ? `Lượt chạy: ${current.id}` : 'Đang hiển thị báo cáo local gần nhất, nếu có.';
        } catch (error) { notice(error.message + ' Kiểm tra cửa sổ dashboard server.'); }
        finally { loading = false; }
    }
    async function run(suite) {
        if (active || !enabled) return;
        if (suite === 'all' && !confirm('Chạy tuần tự toàn bộ test local, gồm cả 3 workload k6 và Android? CI/CD vẫn chạy riêng trên GitHub.')) return;
        document.querySelectorAll('.run, #run-all').forEach(button => button.disabled = true);
        try {
            const form = new FormData(); form.set('suite', suite); form.set('showWindows', $('show-windows').checked);
            form.set('__RequestVerificationToken', document.querySelector('#token input').value);
            const response = await fetch('/dashboard?handler=Run', { method: 'POST', body: form });
            const data = await response.json(); if (!response.ok) throw new Error(data.error || 'Không bắt đầu được test.');
            notice(''); $('execution').scrollIntoView({ behavior: 'smooth', block: 'start' });
        } catch (error) { notice(error.message); }
        await refresh();
    }
    document.querySelectorAll('[data-run]').forEach(button => button.addEventListener('click', () => run(button.dataset.run === 'performance' ? $('profile').value : button.dataset.run)));
    $('run-all').addEventListener('click', () => run('all')); $('refresh').addEventListener('click', refresh);
    refresh(); setInterval(refresh, 1500);
})();
