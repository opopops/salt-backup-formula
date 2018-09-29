{%- from "backup/map.jinja" import backup with context %}

{%- set hostname = salt['grains.get']('host') %}
{%- set date     = salt['cmd.shell']('date +"%Y%m%d%H%M%S"') %}

include:
  - backup.install

{%- for name, params in backup.get('archive', {}).items() %}

  {%- set format    = params.format|default(default_settings.backup.archive.format) %}
  {%- if params.name is defined %}
    {%- if params.prefix_date|default(default_settings.backup.archive.prefix_date) %}
      {%- do params.update({'name': date ~ '_' ~ params.name}) %}
      {%- set dest_file = params.target ~ '/' ~ params.name %}
    {%- else %}
      {%- set dest_file = params.target ~ '/' ~ params.name %}
    {%- endif %}
  {%- else %}
    {%- do params.update({'name': date ~ '_' ~ name ~ '.' ~ format}) %}
    {%- set dest_file   = params.target ~ '/' ~ params.name %}
  {%- endif %}

archive_{{name}}_directory:
  file.directory:
    - name: {{params.target}}

  {%- if format in ['tgz', 'tar.gz'] %}
    {%- set options = params.options|default(default_settings.backup.archive.tgz_options) %}
archive_{{name}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{dest_file}}
    - require:
      - file: archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'tar' %}
    {%- set options = params.options|default(default_settings.backup.archive.tar_options) %}
archive_{{name}}:
  module.run:
    - archive.tar:
      - options: {{options}}
      - sources: {{params.sources}}
      - tarfile: {{dest_file}}
    - require:
      - file: archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'zip' %}
archive_{{name}}:
  module.run:
    - archive.cmd_zip:
      - sources: {{params.sources}}
      - zip_file: {{dest_file}}
    - require:
      - file: archive_{{name}}_directory
      - sls: backup.install
  {%- elif format == 'gzip' %}
archive_{{name}}:
  module.run:
    - archive.gzip:
      - source: {{params.source}}
      - options: {{options}}
    - require:
      - file: archive_{{name}}_directory
      - sls: backup.install
  {%- endif %}

  {%- if params.encryption is defined %}
    {%- if params.encryption.gpg is defined %}
      {%- set gpg_opts = [] %}
      {%- do gpg_opts.append('--passphrase=' ~ params.encryption.gpg.passphrase) %}

archive_{{name}}_encrypt:
  cmd.run:
    - name: gpg --yes --batch {{gpg_opts|join(' ')}} --output {{dest_file}}.sig --recipient {{params.encryption.gpg.recipient}} --sign --encrypt {{dest_file}}
    - output_loglevel: quiet
    - require:
      - module: archive_{{name}}
    - require_in:
      - file: archive_{{name}}_file

archive_{{name}}_clean:
  file.absent:
    - name: {{dest_file}}
    - require:
      - cmd: archive_{{name}}_encrypt

    {%- do params.update({'name': params.name ~ '.sig'}) %}
    {%- set dest_file = dest_file ~ '.sig' %}
    {%- endif %}
  {%- endif %}

archive_{{name}}_file:
  file.managed:
    - name: {{dest_file}}
    - user: {{params.user|default('root')}}
    - group: {{params.group|default('root')}}
    - mode: {{params.mode|default('640')}}
    - replace: False
    - require:
      - module: archive_{{name}}

  {%- if params.retention is defined %}
archive_{{name}}_retention:
  file.retention_schedule:
    - name: {{params.target}}
    - retain: {{params.retention.retain}}
  {%- endif %}

  {%- if params.storage is defined %}
    {%- if params.storage.dropbox is defined %}
      {%- set dropbox_settings = salt['pillar.get']('dropbox', {}) %}
      {%- set path =  params.storage.dropbox.target ~ '/' ~ params.name %}
archive_{{name}}_dropbox:
  cmd.run:
    - name: 'curl -X POST https://content.dropboxapi.com/2/files/upload
                 --header "Authorization: Bearer {{dropbox_settings.apps.get(params.storage.dropbox.app).token}}"
                 --header "Dropbox-API-Arg: {\"path\": \"{{path}}\",\"mode\": \"add\",\"autorename\": true,\"mute\": false}"
                 --header "Content-Type: application/octet-stream"
                 --data-binary @{{dest_file}}'
    {%- endif %}
  {%- endif %}
{%- endfor %}
