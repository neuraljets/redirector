#!/bin/bash

sqlite3 db/redirects.db <<EOF
    CREATE TABLE IF NOT EXISTS redirects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        domain TEXT NOT NULL UNIQUE,
        target_url TEXT NOT NULL
    );
EOF