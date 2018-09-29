{%- from "backup/map.jinja" import backup with context %}

backup_packages:
  pkg.installed:
    - pkgs: {{backup.packages}}
