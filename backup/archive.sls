{%- from "backup/map.jinja" import backup with context %}

include:
  - backup.install
  - backup.mount

{%- for file, params in backup.get('archive', {}).items() %}
  {%- set format = params.get('format', backup.archive_format) %}

backup_archive_{{file}}_directory:
  file.directory:
    - name: {{salt['file.dirname'](file)}}
    - user: {{params.user|default('root')}}
    - group: {{params.group|default('root')}}

  {%- if params.excludefrom is mapping and params.excludefrom.get('path', False) %}
backup_archive_{{file}}_excludefrom:
  file.managed:
    - name: {{params.excludefrom.path}}
    {%- for k, v in params.items() %}
      {%- if k in ['user', 'group', 'mode', 'contents'] %}
    - {{k}}: {{v}}
      {%- endif %}
    {%- endfor %}
    - require_in:
      - module: backup_archive_{{file}}
  {%- endif %}

  {%- if format in ['tgz', 'tar.gz'] %}
    {%- set options = params.options|default(backup.tgz_options) %}
backup_archive_{{file}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{file}}_directory
      - sls: backup.install
  {%- elif format in ['tbz', 'tbz2', 'tar.bz', 'tar.bz2'] %}
    {%- set options = params.options|default(backup.tbz2_options) %}
backup_archive_{{file}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{file}}_directory
      - sls: backup.install
  {%- elif format == 'tar' %}
    {%- set options = params.options|default(backup.tar_options) %}
backup_archive_{{file}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{file}}_directory
      - sls: backup.install
  {%- elif format == 'zip' %}
backup_archive_{{file}}:
  module.run:
    - archive.cmd_zip:
      - sources: {{params.sources}}
      - zip_file: {{file}}
    - require:
      - file: backup_archive_{{file}}_directory
      - sls: backup.install
  {%- elif format == 'gzip' %}
    {%- set options = params.options|default(backup.gzip_options) %}
backup_archive_{{file}}:
  module.run:
    - archive.gzip:
      - source: {{params.source}}
      - options: {{options}}
    - require:
      - file: backup_archive_{{file}}_directory
      - sls: backup.install
  {%- endif %}

  {%- if params.encrypt is defined %}
    {%- if params.encrypt.gpg is defined %}
      {%- set encrypt_file = file ~ params.encrypt.gpg.suffix|default(backup.encrypt_suffx) %}
      {%- set gpg_opts = [] %}
      {%- do gpg_opts.append('--passphrase=' ~ params.encrypt.gpg.passphrase) %}

backup_archive_{{file}}_encrypt:
  cmd.run:
    - name: gpg --yes --batch {{gpg_opts|join(' ')}} --output {{encrypt_file}} --recipient {{params.encrypt.gpg.recipient}} --sign --encrypt {{file}}
    - output_loglevel: quiet
    - require:
      - module: backup_archive_{{file}}
    - require_in:
      - file: backup_archive_{{file}}_file

backup_archive_{{file}}_clean:
  file.absent:
    - name: {{file}}
    - retry:
        attempts: 3
        until: True
        interval: 5
    - require:
      - cmd: backup_archive_{{file}}_encrypt

    {%- endif %}
  {%- endif %}

backup_archive_{{file}}_file:
  file.managed:
    - name: {{encrypt_file|default(file)}}
    - user: {{params.user|default('root')}}
    - group: {{params.group|default('root')}}
    - mode: {{params.mode|default('640')}}
    - replace: False
    - require:
      - module: backup_archive_{{file}}

  {%- if params.retention is defined %}
backup_archive_{{file}}_retention:
  cmd.run:
    - cwd: {{salt['file.dirname'](file)}}
    - name: ls -tr | head -n -{{ params.retention|int - 1 }} | xargs rm -rf
  {%- endif %}

  {%- if params.dropbox is defined %}
backup_archive_{{file}}_dropbox:
  cmd.run:
    - name: 'curl -X POST {{backup.dropbox.upload_url}}
                 --header "Authorization: Bearer {{params.dropbox.token|default(backup.dropbox.token)}}"
                 --header "Dropbox-API-Arg: {\"path\": \"{{params.dropbox.path}}\",\"mode\": \"add\",\"autorename\": true,\"mute\": false}"
                 --header "Content-Type: application/octet-stream"
                 --data-binary @{{encrypt_file|default(file)}}'
    - require:
      - module: backup_archive_{{file}}
  {%- endif %}
{%- endfor %}
