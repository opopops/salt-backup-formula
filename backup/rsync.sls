{%- from "backup/map.jinja" import backup with context %}

{%- set hostname = salt['grains.get']('host') %}
{%- set date     = salt['cmd.shell']('date +"%Y%m%d%H%M%S"') %}

include:
  - backup.install

{%- for name, params in backup.get('rsync', {}).items() %}
backup_rsync_{{name}}:
  rsync.synchronized:
    - name: {{name}}
    {%- for k, v in params.items() %}
      {%- if k not in ['name'] %}
    - {{k}}: {{v}}
      {%- endif %}
    {%- endfor %}
    - require:
      - sls: backup.install
{%- endfor %}
