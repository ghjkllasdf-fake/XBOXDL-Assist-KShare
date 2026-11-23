<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>下载助手 · 软件中心</title>
<link rel="icon" href="/images/favicon.png">
<link rel="stylesheet" href="/index_style.css">
<link rel="stylesheet" href="/form_style.css">
<!-- XBFAST_INLINE_CSS -->
<script src="/state.js"></script>
<script src="/popup.js"></script>
<script src="/help.js"></script>
<script src="/validator.js"></script>
<script src="/js/jquery.js"></script>
<script src="/general.js"></script>
<script src="/dbconf?p=xbfast&amp;v=<% uptime(); %>"></script>
</head>
<body>
<div id="xbfastShell">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" title="固件后台操作" hidden></iframe>
<form id="xbfastFirmwareForm" name="form" method="post" action="/apply.cgi" target="hidden_frame" hidden>
<input type="hidden" name="current_page" value="Module_xbfast.asp">
<input type="hidden" name="next_page" value="Module_xbfast.asp">
<input type="hidden" name="action_mode" value="">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="action_wait" value="">
<input type="hidden" name="group_id" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="first_time" value="">
<input type="hidden" id="preferred_lang" name="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
</form>
<table id="xbfastLayout" class="content" role="presentation" align="center" cellspacing="0" cellpadding="0">
<tbody><tr>
<td class="xbfast-gutter" aria-hidden="true"></td>
<td class="xbfast-sidebar">
<details id="xbfastNavigation" open>
<summary>路由器导航</summary>
<div id="mainMenu"></div>
<div id="subMenu"></div>
</details>
</td>
<td class="xbfast-column">
<div id="tabMenu" class="submenuBlock"></div>
<div id="FormTitle" class="FormTitle FormTable">
<main id="xbfast">
<header class="xbfast-heading">
<div>
<h1 class="formfonttitle">下载助手</h1>
<p class="muted xbfast-version">Koolshare 本地插件 · v0.0.1</p>
</div>
<a class="xbfast-back" href="/Main_Soft_center.asp" title="返回软件中心" aria-label="返回软件中心">
<img src="/images/backprev.png" width="40" height="40" alt="返回软件中心">
</a>
</header>
<noscript>需要开启 JavaScript 才能配置。</noscript>
<section aria-labelledby="serviceHeading">
<h2 id="serviceHeading">服务设置</h2>
<p id="status" class="status" role="status">正在读取设置…</p>
<div class="row">
<label><input id="enabled" type="checkbox"> 启用下载助手</label>
<label><input id="autostart" type="checkbox"> 重启后自动开启并应用</label>
<label><input id="xbox" type="checkbox"> Xbox 下载跳转</label>
<label><input id="store" type="checkbox"> Windows 商店 CDN</label>
</div>
<label for="devices" class="label">加速设备 IPv4</label>
<label><input id="all_devices" type="checkbox"> 对主局域网全部设备生效</label>
<p id="allDevicesHelp" class="muted" hidden>覆盖从主 LAN 进入路由器的本子网 IPv4 设备；独立访客网段和路由器本机不在范围内。已填地址会保留。</p>
<textarea id="devices" class="input_25_table xbfast-input" rows="2" maxlength="400" placeholder="例如 192.168.1.20" aria-describedby="deviceHelp"></textarea>
<p class="muted" id="deviceHelp">最多 16 台，一行一个或用逗号分隔。建议给设备固定 IP，DNS 设为自动；PC 如果启用了加密 DNS，可能绕过本插件。</p>
<details id="knownDetails">
<summary>从路由器已知设备选择</summary>
<button id="refreshDevices" type="button">刷新设备列表</button>
<p id="deviceStatus" class="muted" role="status">读取已有租约和邻居记录，不扫描网络。</p>
<div id="knownDevices" class="nodes" aria-label="已知设备"></div>
</details>
<div class="settings-grid" id="pins"></div>
<p class="muted">节点留空由运营商 DNS 自动选择。手动每组最多 8 个；多选会把这些地址提供给客户端，并不保证按速度顺序使用。</p>
<button id="save" type="button" class="primary">保存并应用</button>
</section>
<section aria-labelledby="testHeading">
<h2 id="testHeading">查找与测试节点</h2>
<div class="row">
<label for="profile">下载分类</label>
<select id="profile"></select>
<button type="button" id="discover">查询运营商 DNS</button>
</div>
<p id="jobStatus" class="status" role="status">先查询当前分类的运营商 DNS，再勾选候选测速。</p>
<div class="nodes" id="nodes"></div>
<div class="row"><label><input id="selectAll" type="checkbox"> 全选候选节点</label></div>
<p class="muted">归属来自随安装包提供的离线快照，仅供参考；不代表 CDN 机房的实际位置。</p>
<div id="storeSample" hidden>
<label for="sample" class="label">商店公开测试文件（可选）</label>
<textarea id="sample" rows="2" maxlength="385" placeholder="粘贴这一组域名的公开下载链接，不含查询参数"></textarea>
</div>
<div class="row compact">
<button id="measure" type="button">测试所选节点</button>
<button id="measureBest" type="button">全选测速并填入最快</button>
<button id="use" type="button">填入所选节点</button>
</div>
<p class="muted">Xbox 用公开文件测短时下载，测试会占用带宽。商店填同组域名的公开文件链接才能测下载速度；不填只测 HTTP 响应时间，不能证明对应文件能下载。填入节点后，还要点「保存并应用」。</p>
</section>
</main>
</div>
</td>
</tr></tbody>
</table>
<div id="footer"></div>
</div>
<script>
window.addEventListener('load', function () {
    'use strict';
    function menuHook() {
        if (!Array.isArray(window.tabtitle) || !Array.isArray(window.tablink) || !window.tablink.length) return;
        var index = window.tablink.findIndex(function (links) {
            return Array.isArray(links) && links.some(function (link) { return /^\/?Main_Soft_center(?:_install)?\.asp$/i.test(link); });
        });
        if (index >= 0 && index < window.tabtitle.length) {
            window.tabtitle[index] = ['', '下载助手'];
            window.tablink[index] = ['', 'Module_xbfast.asp'];
        }
    }
    try {
        if (typeof window.show_menu === 'function') {
            if (window.jQuery && typeof window.jQuery.noConflict === 'function') window.jQuery.noConflict();
            window.show_menu(menuHook);
        }
    } catch (error) {
        console.warn('无法初始化固件导航。', error);
    }
    var profiles = {main:'Xbox 常用游戏下载',legacy:'Xbox One 部分老游戏',store_dl:'商店下载 · dl.delivery',store_tlu:'商店下载 · tlu.dl.delivery'};
    var messages = {running:'试图应用设置…',saved:'已保存',invalid:'设置无效：请检查 IP、数量和所选类型。',failed:'应用失败；已尝试恢复上一次配置。'};
    var runtime = {running:'正在运行',stopped:'已停止',error:'未能启动，请检查日志',cleanup_error:'未能完全停止，防火墙规则可能残留，请重试'};
    var settings = ['enabled','autostart','devices','all_devices','xbox','store','main','legacy','store_dl','store_tlu'];
    var $ = function (id) { return document.getElementById(id); };
    var status = $('status'), jobStatus = $('jobStatus');
    var jobButtons = [$('measure'), $('measureBest'), $('discover'), $('profile'), $('selectAll')];
    function readState() { return window.db_xbfast || window.db_xbfast_ || {}; }
    var state = readState();
    var discovery = null;
    function value(name) { return String(state['xbfast_' + name] || ''); }
    function split(raw) { return raw.trim().split(/[\s,;]+/).filter(Boolean); }
    function unique(values) { return values.filter(function (item, index) { return values.indexOf(item) === index; }); }
    function list(raw) { return split(raw).join('\n'); }
    function validIp(ip) { return /^(0|[1-9]\d{0,2})(\.(0|[1-9]\d{0,2})){3}$/.test(ip) && ip.split('.').every(function (part) { return Number(part) <= 255; }); }
    function post(script, fields) {
        return new Promise(function (resolve, reject) {
            var form = $('xbfastFirmwareForm').cloneNode(true);
            form.removeAttribute('id');
            form.removeAttribute('name');
            form.action = '/applydb.cgi?p=xbfast_';
            form.elements.action_mode.value = ' Refresh ';
            form.elements.action_wait.value = '5';
            function field(name, value) {
                var input = document.createElement('input');
                input.type = 'hidden'; input.name = name; input.value = value; form.appendChild(input);
            }
            field('SystemCmd', script);
            Object.keys(fields).forEach(function (key) { field('xbfast_edit_' + key, fields[key]); });
            document.body.appendChild(form);
            try { form.submit(); resolve(); }
            catch (error) { reject(Error('无法提交到路由器，请重试。')); }
            finally { setTimeout(function () { document.body.removeChild(form); }, 0); }
        });
    }
    function refresh() {
        return new Promise(function (resolve,reject) {
            var script = document.createElement('script');
            script.src = '/dbconf?p=xbfast&v=' + Date.now();
            function finish(error) {
                clearTimeout(timer);
                script.onload = script.onerror = null;
                document.head.removeChild(script);
                if (error) reject(error);
                else { state = readState(); resolve(); }
            }
            var timer = setTimeout(function () { finish(Error('读取路由器状态超时，请重试。')); }, 5000);
            script.onload = function () { finish(); };
            script.onerror = function () { finish(Error('无法读取路由器状态，请重试。')); };
            document.head.appendChild(script);
        });
    }
    function waitFor(key, check, limit, result, failure) {
        var started = Date.now();
        function tick() {
            refresh().then(function () {
                if (value(key) === check && ['running',''].indexOf(result()) < 0) { failure(null); return; }
                if (Date.now() - started > limit) { failure(Error('路由器未返回本次请求的结果，请重试。')); return; }
                setTimeout(tick, 1000);
            }).catch(failure);
        }
        setTimeout(tick, 950);
    }
    function selected() {
        return Array.from($('nodes').querySelectorAll('input:checked')).map(function (item) { return item.value; });
    }
    function allNodes() { return Array.from($('nodes').querySelectorAll('input')); }
    function syncSelection() {
        var all = allNodes().length, checked = selected().length;
        $('selectAll').checked = all > 0 && checked === all;
        $('selectAll').indeterminate = checked > 0 && checked < all;
    }
    function speed(text) {
        return /^(\d+(?:\.\d+)?) Mbps$/.test(text || '') ? Number.parseFloat(text) : -1;
    }
    function renderNodes(ips, tests, checked) {
        var locations = Object.create(null);
        value('locations').split(';').forEach(function (item) {
            var separator = item.indexOf('|');
            if (separator > 0) locations[item.slice(0,separator)] = item.slice(separator+1);
        });
        $('nodes').textContent = '';
        unique(ips).filter(validIp).forEach(function (ip) {
            var label = document.createElement('label'), box = document.createElement('input');
            box.type = 'checkbox'; box.value = ip; box.checked = checked.indexOf(ip) >= 0;
            label.appendChild(box); label.appendChild(document.createTextNode(' ' + ip));
            var location = document.createElement('span'); location.className = 'muted'; location.textContent = ' · ' + (locations[ip] || '归属未知'); label.appendChild(location);
            if (tests[ip]) { var detail = document.createElement('small'); detail.textContent = tests[ip]; label.appendChild(detail); }
            $('nodes').appendChild(label);
        });
        syncSelection();
    }
    Object.keys(profiles).forEach(function (key) {
        var option = document.createElement('option'), group = document.createElement('div'), label = document.createElement('label'), area = document.createElement('textarea');
        option.value = key; option.textContent = profiles[key]; $('profile').appendChild(option);
        label.htmlFor = key; label.className = 'label'; label.textContent = profiles[key];
        area.id = key; area.className = 'input_25_table xbfast-input'; area.rows = 2; area.maxLength = 400; area.placeholder = '留空 = 自动 DNS';
        group.appendChild(label); group.appendChild(area); $('pins').appendChild(group);
    });
    function showSettings() {
        settings.forEach(function (name) {
            if ($(name).type === 'checkbox') $(name).checked = value('cfg_' + name) === '1';
            else $(name).value = list(value('cfg_' + name));
        });
        status.textContent = runtime[value('runtime')] || '尚未启用';
        syncDeviceMode();
        syncDeviceList();
    }
    function syncDeviceMode() {
        var all = $('all_devices').checked;
        $('devices').disabled = all;
        $('knownDetails').hidden = all;
        $('allDevicesHelp').hidden = !all;
    }
    function syncDeviceList() {
        var current = split($('devices').value);
        Array.from($('knownDevices').querySelectorAll('input')).forEach(function (item) { item.checked = current.indexOf(item.value) >= 0; });
    }
    function renderDevices() {
        var container = $('knownDevices');
        container.textContent = '';
        value('known_devices').split(';').forEach(function (row) {
            var pair = row.split('|');
            if (!validIp(pair[0])) return;
            var label = document.createElement('label'), box = document.createElement('input');
            box.type = 'checkbox'; box.value = pair[0];
            label.appendChild(box);
            label.appendChild(document.createTextNode(' ' + pair[0] + ' · ' + (pair[1] || '未知名称')));
            container.appendChild(label);
        });
        syncDeviceList();
    }
    function refreshDevices() {
        var button = $('refreshDevices'), output = $('deviceStatus'), request = String(Date.now());
        if (button.disabled) return;
        button.disabled = true; output.textContent = '正在读取已知设备…';
        function finish(error) {
            button.disabled = false;
            if (error) { output.textContent = error.message; return; }
            renderDevices();
            var count = $('knownDevices').querySelectorAll('input').length;
            output.textContent = count ? count + ' 台已知设备，勾选后加入配置。' : '未发现符合条件的设备，仍可手动输入。';
        }
        post('xbfast_devices.sh', {devices_request:request}).then(function () {
            waitFor('devices_request', request, 10000, function () { return 'done'; }, finish);
        }).catch(finish);
    }
    $('all_devices').onchange = syncDeviceMode;
    $('devices').oninput = syncDeviceList;
    $('knownDetails').ontoggle = function () { if ($('knownDetails').open && !$('knownDevices').children.length) refreshDevices(); };
    $('refreshDevices').onclick = refreshDevices;
    $('knownDevices').onchange = function (event) {
        var box = event.target;
        if (!validIp(box.value)) return;
        var current = unique(split($('devices').value));
        if (box.checked && current.length >= 16) { box.checked = false; $('deviceStatus').textContent = '最多能选择 16 个地址。'; return; }
        current = current.filter(function (ip) { return ip !== box.value; });
        if (box.checked) current.push(box.value);
        $('devices').value = current.join('\n');
    };
    $('save').onclick = function () {
        var fields = {}, invalid = false;
        settings.forEach(function (name) {
            var element = $(name);
            if (element.type === 'checkbox') { fields[name] = element.checked ? '1' : '0'; return; }
            var items = unique(split(element.value));
            if (items.length > (name === 'devices' ? 16 : 8) || items.some(function (ip) { return !validIp(ip); })) invalid = true;
            fields[name] = items.join(' ');
        });
        if (invalid || (fields.enabled === '1' && ((!fields.devices && fields.all_devices !== '1') || fields.xbox + fields.store === '00'))) { status.textContent = messages.invalid; return; }
        fields.request = String(Date.now());
        $('save').disabled = true; status.textContent = messages.running;
        var finish = function (error) {
            $('save').disabled = false;
            if (error) { status.textContent = error.message; return; }
            if (value('state') === 'saved') showSettings();
            status.textContent = (messages[value('state')] || '未知状态') + ' · ' + (runtime[value('runtime')] || '尚未启用');
        };
        var payload = [fields.request,fields.enabled,fields.autostart,fields.xbox,fields.store,fields.devices,fields.main,fields.legacy,fields.store_dl,fields.store_tlu,fields.all_devices,'end'].join('|');
        post('xbfast_config.sh', {save:payload}).then(function () { waitFor('request', fields.request, 30000, function () { return value('state'); }, finish); }).catch(finish);
    };
    function job(operation, autoFill) {
        var profileKey = $('profile').value;
        if (operation === 'test' && (!discovery || discovery.profile !== profileKey || Date.now() >= discovery.expires)) {
            jobStatus.textContent = '没有当前分类的有效候选，请先查询运营商 DNS。'; return;
        }
        if (autoFill && profileKey.indexOf('store_') === 0 && !$('sample').value.trim()) {
            jobStatus.textContent = '请先填入公开商店下载文件链接；仅响应时间不能用来选择下载最快的节点。'; return;
        }
        if (autoFill) { allNodes().forEach(function (item) { item.checked = true; }); syncSelection(); }
        var candidates = operation === 'test' ? unique(selected()).filter(function (ip) { return discovery.ips.indexOf(ip) >= 0; }) : [];
        if (operation === 'test' && !candidates.length) {
            jobStatus.textContent = '请勾选至少一个运营商 DNS 候选。'; return;
        }
        var request = String(Date.now()), fields = {job:operation,profile:profileKey,job_request:request};
        if (operation === 'test') {
            fields.candidates = candidates.join(' ');
            fields.discovery = discovery.request;
            fields.sample = $('sample').value.trim();
        }
        if (fields.sample && (fields.sample.indexOf('?') >= 0 || fields.sample.indexOf('#') >= 0 || /\s/.test(fields.sample))) { jobStatus.textContent = '请使用没有查询参数的公开链接，不要输入带令牌的链接。'; return; }
        jobButtons.forEach(function (button) { button.disabled = true; });
        if (operation === 'discover') { discovery = null; renderNodes([], {}, []); }
        jobStatus.textContent = operation === 'discover' ? '正在查询运营商 DNS…' : '正在逐个测试，请稍候…';
        var finish = function (error) {
            jobButtons.forEach(function (button) { button.disabled = false; });
            var jobState = value('job_state');
            if (error || jobState !== 'done') {
                if (jobState === 'stale_candidates') { discovery = null; renderNodes([], {}, []); }
                var notices = {no_resolvers:'没有可用的运营商 DNS，未使用其他解析器。请检查 WAN 设置后重试。',no_candidates:'运营商 DNS 未返回可用的 IPv4 候选，请稍后重试。',stale_candidates:'候选已失效，请重新查询当前分类。'};
                jobStatus.textContent = error ? error.message : (notices[jobState] || '操作未完成，请重试。'); return;
            }
            if (operation === 'discover') {
                var ips = unique(split(value('candidates'))).filter(validIp).slice(0,16);
                if (!ips.length) { jobStatus.textContent = '运营商 DNS 未返回可用的 IPv4 候选，请重试。'; return; }
                discovery = {profile:profileKey,request:request,expires:Date.now()+300000,ips:ips};
                renderNodes(ips, {}, split($($('profile').value).value));
                jobStatus.textContent = '解析器：' + value('resolvers') + '；返回 ' + ips.length + ' 个候选 IPv4。';
            } else {
                var tests = {};
                for (var index = 1; index <= 16; index++) {
                    var item = value('result_' + index), separator = item.indexOf(' ');
                    if (separator > 0) tests[item.slice(0,separator)] = item.slice(separator+1);
                }
                var sorted = candidates.slice().sort(function (left,right) {
                    var score = function (ip) { var text = tests[ip] || ''; return text.indexOf('Mbps') > 0 ? Number.parseFloat(text) : (text.indexOf('响应 ') === 0 ? 100000 - Number.parseFloat(text.slice(3)) : -1); };
                    return score(right) - score(left);
                });
                renderNodes(sorted.concat(discovery.ips), tests, candidates);
                if (autoFill) {
                    var best = candidates.filter(function (ip) { return speed(tests[ip]) > 0; }).sort(function (left,right) { return speed(tests[right]) - speed(tests[left]); })[0];
                    if (best) {
                        $(profileKey).value = best;
                        allNodes().forEach(function (item) { item.checked = item.value === best; }); syncSelection();
                        jobStatus.textContent = '已填入最快节点 ' + best + '（' + tests[best] + '）；保存后生效。';
                    } else jobStatus.textContent = '没有取得有效下载速度，未改动已填节点。';
                } else jobStatus.textContent = '测试完成。可取消勾选较慢或不通过的节点。';
            }
        };
        post('xbfast_measure.sh', fields).then(function () { waitFor('job_request', request, operation === 'discover' ? 20000 : 100000, function () { return value('job_state'); }, finish); }).catch(finish);
    }
    $('profile').onchange = function () { discovery = null; renderNodes([], {}, []); $('sample').value = ''; $('storeSample').hidden = $('profile').value.indexOf('store_') !== 0; jobStatus.textContent = '请先查询当前分类的运营商 DNS。'; };
    $('discover').onclick = function () { job('discover'); };
    $('measure').onclick = function () { job('test'); };
    $('measureBest').onclick = function () { job('test', true); };
    $('nodes').onchange = syncSelection;
    $('selectAll').onchange = function () { allNodes().forEach(function (item) { item.checked = $('selectAll').checked; }); syncSelection(); };
    $('use').onclick = function () {
        if (!discovery || discovery.profile !== $('profile').value || Date.now() >= discovery.expires) { jobStatus.textContent = '请先重新查询当前分类的运营商 DNS。'; return; }
        var ips = selected().filter(function (ip) { return discovery.ips.indexOf(ip) >= 0; });
        if (!ips.length || ips.length > 8) { jobStatus.textContent = '请勾选 1–8 个节点。'; return; }
        $($('profile').value).value = ips.join('\n'); jobStatus.textContent = '已填入 ' + ips.length + ' 个节点，需保存后生效。';
    };
    showSettings();
    function placeFirmwareNavigation() {
        var narrowScreen = window.matchMedia('(max-width: 760px)');
        var updateNavigation = function (screen) { $('xbfastNavigation').open = !screen.matches; };
        updateNavigation(narrowScreen);
        if (narrowScreen.addEventListener) narrowScreen.addEventListener('change', updateNavigation);
        else if (narrowScreen.addListener) narrowScreen.addListener(updateNavigation);
    }
    if (window.matchMedia) placeFirmwareNavigation();
});
</script>
</body>
</html>
