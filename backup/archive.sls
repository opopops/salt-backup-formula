{%- from "backup/map.jinja" import backup with context %}

include:
  - backup.install

{%- for file, params in backup.get('archive', {}).items() %}

backup_archive_{{name}}_directory:
  file.directory:
    - name: {{salt['file.dirname'](params.file)}}
    - user: {{params.user|default('root')}}
    - group: {{params.group|default('root')}}

  {%- if format in ['tgz', 'tar.gz'] %}
    {%- set options = params.options|default(backup.archive.tgz_options) %}
backup_archive_{{name}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{name}}_directory
      - sls: backup.install
  {%- elif format in ['tbz', 'tbz2', 'tar.bz', 'tar.bz2'] %}
    {%- set options = params.options|default(backup.archive.tbz2_options) %}
backup_archive_{{name}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'tar' %}
    {%- set options = params.options|default(backup.archive.tar_options) %}
backup_archive_{{name}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{file}}
    - require:
      - file: backup_archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'zip' %}
backup_archive_{{name}}:
  module.run:
    - archive.cmd_zip:
      - sources: {{params.sources}}
      - zip_file: {{file}}
    - require:
      - file: backup_archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'gzip' %}
    {%- set options = params.options|default(backup.archive.gzip_options) %}
backup_archive_{{name}}:
  module.run:
    - archive.gzip:
      - source: {{params.source}}
      - options: {{options}}
    - require:
      - file: backup_archive_{{name}}_directory
      - sls: backup.install
  {%- endif %}

  {%- if params.encrypt is defined %}
    {%- if params.encrypt.gpg is defined %}
      {%- set encrypt_file = file ~ params.encrypt.gpg.suffix|default('.sig') %}
      {%- set gpg_opts = [] %}
      {%- do gpg_opts.append('--passphrase=' ~ params.encrypt.gpg.passphrase) %}

backup_archive_{{name}}_encrypt:
  cmd.run:
    - name: gpg --yes --batch {{gpg_opts|join(' ')}} --output {{encrypt_file}} --recipient {{params.encrypt.gpg.recipient}} --sign --encrypt {{file}}
    - output_loglevel: quiet
    - require:
      - module: backup_archive_{{name}}
    - require_in:
      - file: backup_archive_{{name}}_file

backup_archive_{{name}}_clean:
  file.absent:
    - name: {{file}}
    - retry:
      attempts: 3
      until: True
      interval: 5
    - require:
      - cmd: backup_archive_{{name}}_encrypt

    {%- set file = encrypt_file %}
    {%- endif %}
  {%- endif %}

backup_archive_{{name}}_file:
  file.managed:
    - name: {{file}}
    - user: {{params.user|default('root')}}
    - group: {{params.group|default('root')}}
    - mode: {{params.mode|default('640')}}
    - replace: False
    - require:
      - module: backup_archive_{{name}}

  {%- if params.retention is defined %}
backup_archive_{{name}}_retention:
  cmd.run:
    - cwd: {{params.target}}
    - name: ls -tr | head -n -{{ params.retention|int - 1 }} | xargs rm -rf
  {%- endif %}

  {%- if params.dropbox is defined %}
backup_archive_{{name}}_dropbox:
  cmd.run:
    - name: 'curl -X POST {{backup.dropbox.upload_url}}
                 --header "Authorization: Bearer {{params.dropbox.token|default(dropbox.token)}}"
                 --header "Dropbox-API-Arg: {\"path\": \"{{params.dropbox.path}}\",\"mode\": \"add\",\"autorename\": true,\"mute\": false}"
                 --header "Content-Type: application/octet-stream"
                 --data-binary @{{file}}'
  {%- endif %}
{%- endfor %}
