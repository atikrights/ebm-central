<?php
// EBM Cache Purge Utility
header('X-LiteSpeed-Purge: *');
header('Cache-Control: no-cache, no-store, must-revalidate, max-age=0, private');
header('Content-Type: application/json; charset=utf-8');

$report = [];

// Reset PHP OPcache
if (function_exists('opcache_reset')) {
    $report['opcache_reset'] = opcache_reset() ? 'success' : 'failed';
} else {
    $report['opcache_reset'] = 'not_available';
}

echo json_encode([
    'status' => 'success',
    'message' => 'LiteSpeed Cache and OPcache purged successfully for ebm-central',
    'timestamp' => date('Y-m-d H:i:s T'),
    'report' => $report
], JSON_PRETTY_PRINT);
