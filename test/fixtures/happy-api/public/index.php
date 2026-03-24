<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

// Simple router — only /api/happy/{id}
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$uri = parse_url($uri, PHP_URL_PATH);

header('Content-Type: application/json');

if (preg_match('#^/api/happy/(\d+)$#', $uri, $matches)) {
    $id = (int) $matches[1];

    // TODO: Implement HappyService that returns deterministic joke + cat image for given ID
    http_response_code(501);
    echo json_encode([
        'error' => 'Not implemented yet',
        'id' => $id,
    ]);
    exit;
}

http_response_code(404);
echo json_encode([
    'error' => 'Not found',
    'hint' => 'Try /api/happy/{id} where id is a positive integer',
]);
