#!/usr/bin/env php
<?php

declare(strict_types=1);

if ($argc < 4) {
    fwrite(STDERR, "Uso: php update_env_value.php <arquivo> <chave> <valor>\n");
    exit(1);
}

$file = $argv[1];
$key = $argv[2];
$value = $argv[3];

function serialize_env_value(string $value): string
{
    if ($value === '') {
        return '';
    }

    if (preg_match('/^[A-Za-z0-9_\\/.:-]+$/', $value) === 1) {
        return $value;
    }

    return '"' . strtr($value, [
        '\\' => '\\\\',
        '"' => '\\"',
        '$' => '\\$',
    ]) . '"';
}

$lines = file_exists($file) ? file($file, FILE_IGNORE_NEW_LINES) : [];
$pattern = '/^\s*#?\s*' . preg_quote($key, '/') . '\s*=.*$/';
$output = [];
$found = false;

foreach ($lines as $line) {
    if (preg_match($pattern, $line) === 1) {
        if (! $found) {
            $output[] = $key . '=' . serialize_env_value($value);
            $found = true;
        }

        continue;
    }

    $output[] = $line;
}

if (! $found) {
    $output[] = $key . '=' . serialize_env_value($value);
}

file_put_contents($file, implode(PHP_EOL, $output) . PHP_EOL);
