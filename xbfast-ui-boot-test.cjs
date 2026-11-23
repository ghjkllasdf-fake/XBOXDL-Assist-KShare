const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const page = fs.readFileSync(process.argv[2] || path.join(__dirname, 'xbfast-ui.asp'), 'utf8');
assert.doesNotMatch(page, /updateGeo|xbfast_geo\.sh|edit_geo_request/);
const chrome = process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const state = { xbfast_cfg_devices: '192.0.2.6', xbfast_runtime: 'running' };
const submissions = [];

function render(firmware) {
    return page.replace(/<script src="[^\"]*"><\/script>|<link[^>]*>/g, '')
        .replace('</head>', `<script>
            window.db_xbfast = ${JSON.stringify(state)};
            window.addEventListener('error', (event) => { document.body.dataset.testError = event.message; });
            ${firmware === 'clone' ? `window.show_menu = function () {
                const container = document.getElementById('tabMenu').parentNode;
                const wrapper = document.createElement('div');
                for (const child of container.children) wrapper.appendChild(child.cloneNode(true));
                container.innerHTML = '';
                container.appendChild(wrapper);
                document.body.dataset.firmwareClone = 'yes';
            };` : firmware === 'throws' ? `window.show_menu = function () { throw new Error('test firmware menu failure'); };` : ''}
        </script></head>`)
        .replace('</body>', `<script>
            window.addEventListener('load', () => {
                const get = (id) => document.getElementById(id);
                const query = get('discover');
                const devices = get('refreshDevices');
                document.body.dataset.handlers = [query, devices, get('save')]
                    .every((button) => typeof button.onclick === 'function') ? 'ready' : 'missing';
                query.click();
                if (!query.disabled || !get('jobStatus').textContent.includes('正在查询')) return;
                document.body.dataset.queryProgress = 'yes';
                const status = new MutationObserver(() => {
                    if (!get('jobStatus').textContent.includes('1 个候选')) return;
                    status.disconnect();
                    devices.click();
                    if (!devices.disabled || !get('deviceStatus').textContent.includes('正在读取')) return;
                    const deviceStatus = new MutationObserver(() => {
                        if (!get('deviceStatus').textContent.includes('1 台已知设备')) return;
                        deviceStatus.disconnect();
                        if (!query.disabled && !devices.disabled && get('devices').value === '192.0.2.6' &&
                            get('nodes').querySelectorAll('input').length === 1 &&
                            get('knownDevices').querySelectorAll('input:checked').length === 1) {
                            document.body.dataset.testResult = 'pass';
                        }
                    });
                    deviceStatus.observe(get('deviceStatus'), { childList: true });
                });
                status.observe(get('jobStatus'), { childList: true });
            });
        </script></body>`);
}

function runChrome(url) {
    const temp = fs.realpathSync(os.tmpdir());
    const profile = fs.mkdtempSync(path.join(temp, 'xbfast-ui-boot-'));
    return new Promise((resolve, reject) => {
        const child = spawn(chrome, ['--headless', '--disable-gpu', '--disable-background-networking', '--no-first-run',
            `--user-data-dir=${profile}`, '--virtual-time-budget=6000', '--dump-dom', url], { windowsHide: true });
        let output = '';
        let errors = '';
        const timer = setTimeout(() => child.kill(), 20000);
        child.stdout.setEncoding('utf8').on('data', (data) => { output += data; });
        child.stderr.setEncoding('utf8').on('data', (data) => { errors += data; });
        child.on('error', reject);
        child.on('close', (code) => {
            clearTimeout(timer);
            try {
                const resolved = fs.realpathSync(profile);
                if (resolved === profile && path.dirname(resolved) === temp && path.basename(resolved).startsWith('xbfast-ui-boot-')) {
                    fs.rmSync(resolved, { recursive: true, force: true, maxRetries: 3 });
                }
            } catch {}
            if (code === 0) resolve(output);
            else reject(new Error(`Chrome exit ${code}: ${errors}`));
        });
    });
}

const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://127.0.0.1');
    if (request.method === 'POST' && url.pathname === '/applydb.cgi') {
        let body = '';
        request.setEncoding('utf8').on('data', (part) => { body += part; }).on('end', () => {
            const fields = new URLSearchParams(body);
            const script = fields.get('SystemCmd');
            if (script === 'xbfast_measure.sh') {
                const id = fields.get('xbfast_edit_job_request');
                submissions.push([script, id]);
                Object.assign(state, { xbfast_job_request: id, xbfast_job_state: 'done', xbfast_candidates: '192.0.2.9' });
            } else if (script === 'xbfast_devices.sh') {
                const id = fields.get('xbfast_edit_devices_request');
                submissions.push([script, id]);
                Object.assign(state, { xbfast_devices_request: id, xbfast_known_devices: '192.0.2.6|fixture' });
            }
            response.end('ok');
        });
    } else if (url.pathname === '/dbconf') {
        response.setHeader('Content-Type', 'text/javascript');
        response.end(`window.db_xbfast = ${JSON.stringify(state)};`);
    } else if (url.pathname === '/Module_xbfast.asp') {
        response.setHeader('Content-Type', 'text/html; charset=utf-8');
        response.end(render(url.searchParams.get('firmware')));
    } else {
        response.writeHead(404).end();
    }
});

server.listen(0, '127.0.0.1', async () => {
    try {
        for (const firmware of ['clone', 'absent', 'throws']) {
            submissions.length = 0;
            const dom = await runChrome(`http://127.0.0.1:${server.address().port}/Module_xbfast.asp?firmware=${firmware}`);
            const body = dom.match(/<body[^>]*>/)?.[0] || '';
            if (firmware === 'clone') assert.match(body, /data-firmware-clone="yes"/);
            assert.match(body, /data-handlers="ready"/, `${firmware}: ${body}`);
            assert.match(body, /data-test-result="pass"/, `${firmware}: ${body}`);
            assert.doesNotMatch(body, /data-test-error=/);
            assert.deepEqual(submissions.map(([script]) => script), ['xbfast_measure.sh', 'xbfast_devices.sh']);
            submissions.forEach(([, id]) => assert.match(id, /^\d{13}$/));
            console.log(`PASS ${firmware}: handlers, immediate progress, both request/ack pairs, and preserved device input`);
        }
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    } finally {
        server.close();
    }
});
