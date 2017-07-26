child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

project_root = process.env.PROJECT_ROOT
if /versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test project_root
  project_root = path.resolve project_root, '..', '..', 'current'

config = yaml.safeLoad(fs.readFileSync project_root + '/deploy.yaml', 'utf-8')

# add jobs in cron_jobs
if Array.isArray config.cron_jobs
  crontab = config.cron_jobs.map (job) ->
    "#{job.pattern} #{project_root}/run_job.sh #{job.job}"
else
  crontab = []

# add jobs in cron_jobs_dir
if config.cron_jobs_dir
  cron_jobs_dir = path.resolve project_root, config.cron_jobs_dir
  files = fs.readdirSync cron_jobs_dir
  for file in files
    continue if not /\.coffee/.test file
    lines = fs.readFileSync(path.resolve(cron_jobs_dir, file), 'utf-8').split '\n'
    for line in lines
      if /^#\s*cron: (.*)$/.test line
        crontab.push "#{RegExp.$1} #{project_root}/run_job.sh #{file.substr 0, file.length-7}"

if config.workers
  # add run-worker-on-boot job
  crontab.push "@reboot #{project_root}/on_boot.sh"

  # add logrotate job
  crontab.push "0 * * * * cd #{project_root} && /usr/sbin/logrotate -s #{process.env.HOME}/.croquis/logrotate_#{config.project}.status logrotate.conf"

# install crontab
crontab = 'CONTENT_TYPE="text/plain; charset=utf-8"\n' + crontab.join('\n') + '\n'

fs.writeFileSync "#{project_root}/.crontab", crontab
try child_process.execSync "crontab -l | grep -v #{project_root} | grep -v CONTENT_TYPE >> #{project_root}/.crontab"
try child_process.execSync "crontab #{project_root}/.crontab"
