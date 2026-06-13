#!/usr/bin/env python3
import os, time, threading, subprocess, glob, markdown
from flask import Flask, jsonify, render_template, send_from_directory, abort

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

P = os.environ.get('HOST_PREFIX', '')
BLOG_DIR = os.environ.get('BLOG_DIR', os.path.join(BASE_DIR, 'blog_content'))

def pjoin(*paths):
    return os.path.join(P, *paths) if P else os.path.join(*paths)

def read_int(path):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except:
        return 0

def get_cpu_percent():
    try:
        with open(pjoin('proc', 'stat')) as f:
            l1 = [float(x) for x in f.readline().split()[1:]]
        time.sleep(0.5)
        with open(pjoin('proc', 'stat')) as f:
            l2 = [float(x) for x in f.readline().split()[1:]]
        total = sum(l2) - sum(l1)
        idle = l2[3] - l1[3]
        return round((1 - idle / total) * 100, 1) if total else 0
    except:
        return 0

def get_cpu_temp():
    for i in range(10):
        t = read_int(pjoin('sys', 'class', 'thermal', f'thermal_zone{i}', 'temp'))
        if t and t > 0:
            return round(t / 1000, 1)
    return 0

def get_cpu_freq():
    for p in [
        pjoin('sys', 'devices', 'system', 'cpu', 'cpu0', 'cpufreq', 'scaling_cur_freq'),
        pjoin('sys', 'devices', 'system', 'cpu', 'cpu0', 'cpufreq', 'cpuinfo_cur_freq')
    ]:
        f = read_int(p)
        if f:
            return round(f / 1000)
    return 0

def get_mem_info():
    mem = {}
    try:
        for line in open(pjoin('proc', 'meminfo')):
            parts = line.split(':')
            if len(parts) == 2:
                try:
                    mem[parts[0].strip()] = int(parts[1].strip().split()[0])
                except:
                    pass
    except:
        pass
    return mem

def get_disk_usage():
    root = pjoin('root') if P else '/'
    try:
        s = os.statvfs(root)
        total = s.f_frsize * s.f_blocks
        used = total - (s.f_frsize * s.f_bfree)
        percent = round(used / total * 100, 1) if total else 0
        return {'total': total, 'used': used, 'percent': percent}
    except:
        return {'total': 0, 'used': 0, 'percent': 0}

def get_net_bytes(iface):
    try:
        for line in open(pjoin('proc', 'net', 'dev')):
            if iface in line and ':' in line:
                parts = line.split()
                return int(parts[1]), int(parts[9])
    except:
        pass
    return 0, 0

def detect_iface():
    try:
        for line in open(pjoin('proc', 'net', 'route')):
            parts = line.strip().split()
            if len(parts) >= 2 and parts[1] == '00000000':
                return parts[0]
    except:
        pass
    try:
        for line in open(pjoin('proc', 'net', 'dev')):
            if ':' in line:
                iface = line.split(':')[0].strip()
                if iface not in ('lo', 'docker0') and not iface.startswith(('br-', 'veth', 'dummy')):
                    return iface
    except:
        pass
    return 'eth0'

def get_ip():
    try:
        r = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=3)
        for ip in r.stdout.strip().split():
            if ip.count('.') == 3:
                return ip
    except:
        pass
    return 'N/A'

def get_uptime():
    try:
        sec = float(open(pjoin('proc', 'uptime')).read().split()[0])
        d = int(sec // 86400); h = int((sec % 86400) // 3600); m = int((sec % 3600) // 60)
        return f'{d}d {h}h {m}m' if d else f'{h}h {m}m'
    except:
        return 'N/A'

stats = {
    'cpu_percent': 0, 'cpu_temp': 0, 'cpu_freq': 0,
    'ram_total': 0, 'ram_used': 0, 'ram_percent': 0,
    'zram_total': 0, 'zram_used': 0, 'zram_percent': 0,
    'swap_total': 0, 'swap_used': 0, 'swap_percent': 0,
    'disk_total': 0, 'disk_used': 0, 'disk_percent': 0,
    'rx_bytes': 0, 'tx_bytes': 0, 'rx_speed': 0, 'tx_speed': 0,
    'hostname': '', 'ip': '', 'uptime': '',
}

def monitor():
    global stats
    prev_rx = prev_tx = 0
    prev_t = time.time()
    iface = detect_iface()
    while True:
        cpu_percent = get_cpu_percent()
        cpu_temp = get_cpu_temp()
        cpu_freq = get_cpu_freq()
        mem = get_mem_info()
        mt = mem.get('MemTotal', 0)
        ma = mem.get('MemAvailable', 0)
        mu = mt - ma
        rp = round(mu / mt * 100, 1) if mt else 0
        st = mem.get('SwapTotal', 0)
        zu = mem.get('SwapCached', 0)
        zp = round(zu / st * 100, 1) if st else 0
        sf = mem.get('SwapFree', 0)
        su = st - sf
        sp = round(su / st * 100, 1) if st else 0
        disk = get_disk_usage()
        rx, tx = get_net_bytes(iface)
        now = time.time()
        dt = now - prev_t
        rs = (rx - prev_rx) / dt if dt > 0 else 0
        ts = (tx - prev_tx) / dt if dt > 0 else 0
        prev_rx, prev_tx, prev_t = rx, tx, now
        hostname = os.uname().nodename
        ip = get_ip()
        uptime = get_uptime()
        stats.update({
            'cpu_percent': cpu_percent, 'cpu_temp': cpu_temp, 'cpu_freq': cpu_freq,
            'ram_total': mt, 'ram_used': mu, 'ram_percent': rp,
            'zram_total': st, 'zram_used': zu, 'zram_percent': zp,
            'swap_total': st, 'swap_used': su, 'swap_percent': sp,
            'disk_total': disk['total'], 'disk_used': disk['used'], 'disk_percent': disk['percent'],
            'rx_bytes': rx, 'tx_bytes': tx, 'rx_speed': rs, 'tx_speed': ts,
            'hostname': hostname, 'ip': ip, 'uptime': uptime,
        })

def fmt(b):
    for u in ['B', 'KB', 'MB', 'GB', 'TB']:
        if b < 1024:
            return f'{b:.1f} {u}'
        b /= 1024
    return f'{b:.1f} PB'

@app.route('/api/stats')
def api_stats():
    s = stats
    return jsonify({
        'cpu_percent': s['cpu_percent'], 'cpu_temp': s['cpu_temp'], 'cpu_freq': s['cpu_freq'],
        'ram_used': s['ram_used'], 'ram_total': s['ram_total'], 'ram_percent': s['ram_percent'],
        'ram_used_fmt': fmt(s['ram_used']), 'ram_total_fmt': fmt(s['ram_total']),
        'zram_percent': s['zram_percent'],
        'zram_used_fmt': fmt(s['zram_used']), 'zram_total_fmt': fmt(s['zram_total']),
        'swap_percent': s['swap_percent'],
        'swap_used_fmt': fmt(s['swap_used']), 'swap_total_fmt': fmt(s['swap_total']),
        'disk_percent': s['disk_percent'],
        'disk_used_fmt': fmt(s['disk_used']), 'disk_total_fmt': fmt(s['disk_total']),
        'rx_speed': fmt(s['rx_speed']), 'tx_speed': fmt(s['tx_speed']),
        'rx_total_fmt': fmt(s['rx_bytes']), 'tx_total_fmt': fmt(s['tx_bytes']),
        'hostname': s['hostname'], 'ip': s['ip'], 'uptime': s['uptime'],
    })

@app.route('/')
def index():
    return render_template('index.html')

def parse_post(filepath):
    try:
        with open(filepath, encoding='utf-8') as f:
            content = f.read()
    except:
        return None
    lines = content.split('\n')
    title = 'Untitled'
    body = content
    for i, line in enumerate(lines):
        if line.startswith('# '):
            title = line[2:].strip()
            body = '\n'.join(lines[i+1:])
            break
    html = markdown.markdown(body, extensions=['fenced_code'])
    return {'title': title, 'html': html, 'slug': os.path.splitext(os.path.basename(filepath))[0]}

def get_posts():
    posts = []
    pattern = os.path.join(BLOG_DIR, '*.md')
    for fp in sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True):
        p = parse_post(fp)
        if p:
            mtime = os.path.getmtime(fp)
            p['date'] = time.strftime('%d %B %Y', time.localtime(mtime))
            words = len(p['html'].split())
            p['read_time'] = max(1, round(words / 200))
            posts.append(p)
    return posts

@app.route('/blog')
def blog_list():
    return render_template('blog.html', posts=get_posts())

@app.route('/blog/<slug>')
def blog_post(slug):
    fp = os.path.join(BLOG_DIR, slug + '.md')
    if not os.path.isfile(fp):
        abort(404)
    p = parse_post(fp)
    if not p:
        abort(404)
    mtime = os.path.getmtime(fp)
    p['date'] = time.strftime('%d %B %Y', time.localtime(mtime))
    p['read_time'] = max(1, round(len(p['html'].split()) / 200))
    return render_template('blog_post.html', post=p)

if __name__ == '__main__':
    t = threading.Thread(target=monitor, daemon=True)
    t.start()
    time.sleep(1)
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
