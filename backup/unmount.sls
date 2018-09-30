{%- from "backup/map.jinja" import backup with context %}

{%- for name, params in backup.get('mounts', {}).items() %}
  {%- if not params.persist|default(False) %}
backup_unmount_{{name}}:
  mount.unmounted:
    - name: {{name}}
  {%- endif %}
{%- endfor %}
