#!/bin/bash

su - postgres -c '/usr/local/bin/wal-g backup-push /var/lib/postgresql/12/main'