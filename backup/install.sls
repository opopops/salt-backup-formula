{%- from "backup/map.jinja" import backup with context %}

{%- set hostname = salt['grains.get']('host') %}
{%- set date     = salt['cmd.shell']('date +"%Y%m%d%H%M%S"') %}

backup_packages:
  pkg.installed:
    - pkgs: {{backup.packages}}
