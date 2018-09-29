{%- from "backup/map.jinja" import backup with context %}

include:
  - backup.install
  - backup.mount
  - backup.rsync
  - backup.archive
  - backup.unmount
