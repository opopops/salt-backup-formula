{%- from "backup/map.jinja" import backup with context %}

{%- set hostname = salt['grains.get']('host') %}
{%- set date     = salt['cmd.shell']('date +"%Y%m%d%H%M%S"') %}

{%- for name, params in backup.get('mounts', {}).items() %}
backup_mount_{{name}}:
  mount.mounted:
    - name: {{params.name}}
    - device: {{params.device}}
    - fstype: {{params.fstype}}
    - mkmnt: {{params.mkmnt|default(True)}}
    - persist: {{params.persist|default(False)}}
{%- endfor %}
