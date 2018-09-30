{%- from "backup/map.jinja" import backup with context %}

{%- for name, params in backup.get('mounts', {}).items() %}
backup_mount_{{name}}:
  mount.mounted:
    - name: {{name}}
    - device: {{params.device}}
    - fstype: {{params.fstype}}
    - mkmnt: {{params.mkmnt|default(True)}}
    - persist: {{params.persist|default(False)}}
{%- endfor %}
