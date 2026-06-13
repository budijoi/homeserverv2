<?php
session_start();
header('Content-Type: application/json; charset=utf-8');

define('DB_FILE', __DIR__ . '/database.json');
define('PIN', '170884');

function readDB() {
    if (!file_exists(DB_FILE)) {
        $default = [
            'posts' => [],
            'comments' => [],
            'likes' => [],
            'liked_sessions' => [],
            'visitors' => 0,
            'visited_sessions' => [],
            'last_id' => 0
        ];
        file_put_contents(DB_FILE, json_encode($default, JSON_PRETTY_PRINT), LOCK_EX);
        return $default;
    }
    $data = file_get_contents(DB_FILE);
    return json_decode($data, true) ?: [];
}

function writeDB($db) {
    $fp = fopen(DB_FILE, 'c');
    if ($fp && flock($fp, LOCK_EX)) {
        ftruncate($fp, 0);
        fwrite($fp, json_encode($db, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        fflush($fp);
        flock($fp, LOCK_UN);
        fclose($fp);
    }
}

function json($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$action = $_REQUEST['action'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];

if ($action === 'list' && $method === 'GET') {
    $db = readDB();
    $list = array_map(function($p) {
        return [
            'id' => $p['id'],
            'title' => $p['title'],
            'date' => $p['date']
        ];
    }, $db['posts']);
    json(['ok' => true, 'posts' => $list]);
}

if ($action === 'get' && $method === 'GET') {
    $id = $_GET['id'] ?? '';
    $db = readDB();
    $post = null;
    foreach ($db['posts'] as $p) {
        if ($p['id'] === $id) { $post = $p; break; }
    }
    if (!$post) json(['ok' => false, 'error' => 'Post not found']);
    $isLiked = in_array(session_id(), $db['liked_sessions'][$id] ?? []);
    json(['ok' => true, 'post' => $post, 'liked' => $isLiked, 'likes' => $db['likes'][$id] ?? 0, 'comments' => $db['comments'][$id] ?? []]);
}

if ($action === 'save' && $method === 'POST') {
    if (empty($_SESSION['auth'])) json(['ok' => false, 'error' => 'Unauthorized']);
    $title = trim($_POST['title'] ?? '');
    $content = trim($_POST['content'] ?? '');
    $id = $_POST['id'] ?? '';
    if (!$title || !$content) json(['ok' => false, 'error' => 'Judul dan konten wajib diisi']);
    $db = readDB();
    if ($id) {
        foreach ($db['posts'] as &$p) {
            if ($p['id'] === $id) { $p['title'] = $title; $p['content'] = $content; break; }
        }
    } else {
        $db['last_id']++;
        $newId = (string)$db['last_id'];
        $db['posts'][] = ['id' => $newId, 'title' => $title, 'content' => $content, 'date' => date('c')];
        if (!isset($db['comments'][$newId])) $db['comments'][$newId] = [];
        if (!isset($db['likes'][$newId])) $db['likes'][$newId] = 0;
        if (!isset($db['liked_sessions'][$newId])) $db['liked_sessions'][$newId] = [];
    }
    writeDB($db);
    json(['ok' => true]);
}

if ($action === 'delete' && $method === 'POST') {
    if (empty($_SESSION['auth'])) json(['ok' => false, 'error' => 'Unauthorized']);
    $id = $_POST['id'] ?? '';
    if (!$id) json(['ok' => false, 'error' => 'ID required']);
    $db = readDB();
    $db['posts'] = array_values(array_filter($db['posts'], fn($p) => $p['id'] !== $id));
    unset($db['comments'][$id], $db['likes'][$id], $db['liked_sessions'][$id]);
    writeDB($db);
    json(['ok' => true]);
}

if ($action === 'like' && $method === 'POST') {
    $id = $_POST['id'] ?? '';
    if (!$id) json(['ok' => false, 'error' => 'ID required']);
    $db = readDB();
    if (!isset($db['likes'][$id])) $db['likes'][$id] = 0;
    if (!isset($db['liked_sessions'][$id])) $db['liked_sessions'][$id] = [];
    $sid = session_id();
    $isLiked = in_array($sid, $db['liked_sessions'][$id]);
    if ($isLiked) {
        $db['likes'][$id] = max(0, $db['likes'][$id] - 1);
        $db['liked_sessions'][$id] = array_values(array_filter($db['liked_sessions'][$id], fn($s) => $s !== $sid));
    } else {
        $db['likes'][$id]++;
        $db['liked_sessions'][$id][] = $sid;
    }
    writeDB($db);
    json(['ok' => true, 'liked' => !$isLiked, 'count' => $db['likes'][$id]]);
}

if ($action === 'comment' && $method === 'POST') {
    $id = $_POST['id'] ?? '';
    $name = trim($_POST['name'] ?? 'Anonim');
    $text = trim($_POST['text'] ?? '');
    if (!$text) json(['ok' => false, 'error' => 'Teks komentar tidak boleh kosong']);
    $db = readDB();
    if (!isset($db['comments'][$id])) $db['comments'][$id] = [];
    $db['comments'][$id][] = ['name' => $name ?: 'Anonim', 'text' => $text, 'date' => date('c')];
    writeDB($db);
    json(['ok' => true]);
}

if ($action === 'visitor' && $method === 'GET') {
    $db = readDB();
    json(['ok' => true, 'count' => $db['visitors']]);
}

if ($action === 'visit' && $method === 'POST') {
    $db = readDB();
    $sid = session_id();
    if (!in_array($sid, $db['visited_sessions'] ?? [])) {
        $db['visitors'] = ($db['visitors'] ?? 0) + 1;
        $db['visited_sessions'][] = $sid;
        writeDB($db);
    }
    json(['ok' => true, 'count' => $db['visitors']]);
}

if ($action === 'checkAuth' && $method === 'GET') {
    json(['ok' => true, 'auth' => !empty($_SESSION['auth'])]);
}

if ($action === 'login' && $method === 'POST') {
    $pin = $_POST['pin'] ?? '';
    if ($pin === PIN) {
        $_SESSION['auth'] = true;
        json(['ok' => true]);
    } else {
        json(['ok' => false, 'error' => 'PIN salah']);
    }
}

if ($action === 'logout' && $method === 'POST') {
    $_SESSION['auth'] = false;
    session_destroy();
    json(['ok' => true]);
}

json(['ok' => false, 'error' => 'Unknown action']);
