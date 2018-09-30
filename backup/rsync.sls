{%- from "backup/map.jinja" import backup with context %}

include:
  - backup.install

{%- for source, params in backup.get('rsync', {}).items() %}

  {%- if params.excludefrom is mapping and params.excludefrom.get('path', False) %}
backup_rsync_{{source}}_excludefrom:
  file.managed:
    - name: {{params.excludefrom.path}}
    {%- for k, v in params.items() %}
      {%- if k in ['user', 'group', 'mode', 'contents'] %}
    - {{k}}: {{v}}
      {%- endif %}
    {%- endfor %}
    - require_in:
      - rsync: backup_rsync_{{source}}
  {%- endif %}

backup_rsync_{{source}}:
  rsync.synchronized:
    - name: {{params.target}}
    - source: {{params.source}}
    {%- if params.get('excludefrom', False) %}
      {%- if params.excludefrom is mapping and params.excludefrom.get('path', False) %}
    - excludefrom: {{params.excludefrom.path}}
      {%- else %}
    - excludefrom: {{params.excludefrom}}
      {%- endif %}
    {%- endif %}
    {%- for k, v in params.items() %}
      {%- if k not in ['name', 'target', 'source', 'excludefrom'] %}
    - {{k}}: {{v}}
      {%- endif %}
    {%- endfor %}
    - require:
      - sls: backup.install
{%- endfor %}
